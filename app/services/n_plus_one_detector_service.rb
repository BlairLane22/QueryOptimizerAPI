class NPlusOneDetectorService
  attr_reader :queries, :time_window, :threshold

  def initialize(queries, time_window: 5.seconds, threshold: 3)
    @queries = queries.sort_by(&:analyzed_at)
    @time_window = time_window
    @threshold = threshold
  end

  def self.detect(queries, **options)
    new(queries, **options).detect
  end

  def detect
    n_plus_one_patterns = []

    # Group queries by their normalized signature
    query_groups = group_queries_by_signature

    query_groups.each do |signature, grouped_queries|
      next if grouped_queries.length < threshold

      # Check if queries are clustered in time (indicating N+1 pattern)
      time_clusters = find_time_clusters(grouped_queries)

      time_clusters.each do |cluster|
        next if cluster.length < threshold

        pattern = analyze_cluster_for_n_plus_one(cluster)
        n_plus_one_patterns << pattern if pattern
      end
    end

    n_plus_one_patterns
  end

  private

  def group_queries_by_signature
    queries.group_by do |query|
      parser = SqlParserService.new(query.sql_query)
      parser.query_signature
    end
  end

  def find_time_clusters(queries)
    clusters = []
    current_cluster = []
    
    queries.each do |query|
      if current_cluster.empty?
        current_cluster = [query]
      else
        time_diff = query.analyzed_at - current_cluster.last.analyzed_at
        
        if time_diff <= time_window
          current_cluster << query
        else
          clusters << current_cluster if current_cluster.length >= threshold
          current_cluster = [query]
        end
      end
    end
    
    clusters << current_cluster if current_cluster.length >= threshold
    clusters
  end

  def analyze_cluster_for_n_plus_one(cluster)
    # Parse the first query to understand the pattern
    first_query = cluster.first
    parser = SqlParserService.new(first_query.sql_query)
    
    return nil unless parser.valid?
    return nil unless parser.query_type == 'SELECT'
    return nil unless parser.potential_n_plus_one?
    
    # Verify all queries in cluster have same structure but different parameters
    return nil unless all_queries_similar_structure?(cluster)
    
    # Extract the pattern details
    where_conditions = parser.where_conditions
    id_condition = where_conditions.find do |c|
      column = c[:column]
      column && column.match?(/\bid\b|_id$/i)
    end

    return nil unless id_condition
    
    {
      type: 'n_plus_one',
      table_name: parser.primary_table,
      column_name: id_condition[:column],
      query_count: cluster.length,
      time_span: cluster.last.analyzed_at - cluster.first.analyzed_at,
      first_query: first_query,
      sample_queries: cluster.first(5), # Keep first 5 as samples
      pattern_signature: parser.query_signature,
      severity: calculate_severity(cluster.length),
      suggestion: generate_suggestion(parser, cluster)
    }
  end

  def all_queries_similar_structure?(cluster)
    return true if cluster.length <= 1
    
    first_signature = SqlParserService.new(cluster.first.sql_query).query_signature
    
    cluster.all? do |query|
      SqlParserService.new(query.sql_query).query_signature == first_signature
    end
  end

  def calculate_severity(query_count)
    case query_count
    when 0..5
      'low'
    when 6..15
      'medium'
    when 16..50
      'high'
    else
      'critical'
    end
  end

  def generate_suggestion(parser, cluster)
    table_name = parser.primary_table
    where_conditions = parser.where_conditions
    id_condition = where_conditions.find do |c|
      column = c[:column]
      column && column.match?(/\bid\b|_id$/i)
    end
    
    if id_condition
      foreign_key = id_condition[:column]
      
      if foreign_key.end_with?('_id')
        # This looks like a foreign key lookup
        association_name = foreign_key.gsub('_id', '').pluralize
        
        {
          title: "Use includes() to avoid N+1 queries",
          description: "Detected #{cluster.length} similar queries on #{table_name} table. " \
                      "This appears to be an N+1 query pattern where you're loading #{table_name} " \
                      "records one by one instead of using eager loading.",
          rails_suggestion: "Use `includes(:#{association_name})` or `preload(:#{association_name})` " \
                           "to load all related records in a single query.",
          example_code: "# Instead of:\n" \
                       "users.each { |user| user.#{association_name}.count }\n\n" \
                       "# Use:\n" \
                       "users.includes(:#{association_name}).each { |user| user.#{association_name}.count }",
          sql_suggestion: "Consider using a JOIN or IN clause to fetch all records at once."
        }
      else
        {
          title: "Optimize repeated ID lookups",
          description: "Detected #{cluster.length} similar queries looking up records by ID. " \
                      "Consider batching these lookups.",
          rails_suggestion: "Use `where(id: [id1, id2, id3])` to fetch multiple records at once.",
          example_code: "# Instead of multiple queries:\n" \
                       "ids.each { |id| #{table_name.classify}.find(id) }\n\n" \
                       "# Use:\n" \
                       "#{table_name.classify}.where(id: ids)",
          sql_suggestion: "Use WHERE id IN (...) to fetch multiple records in a single query."
        }
      end
    else
      {
        title: "Optimize repeated queries",
        description: "Detected #{cluster.length} similar queries that could be optimized.",
        rails_suggestion: "Consider batching these queries or using eager loading.",
        sql_suggestion: "Analyze the query pattern and consider using JOINs or IN clauses."
      }
    end
  end
end
