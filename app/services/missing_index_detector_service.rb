class MissingIndexDetectorService
  attr_reader :queries, :frequency_threshold

  def initialize(queries, frequency_threshold: 3)
    @queries = Array(queries)
    @frequency_threshold = frequency_threshold
  end

  def self.detect(queries, **options)
    new(queries, **options).detect
  end

  def detect
    index_suggestions = []
    
    # Group queries by table and analyze patterns
    table_queries = group_queries_by_table
    
    table_queries.each do |table_name, table_queries_list|
      suggestions = analyze_table_queries(table_name, table_queries_list)
      index_suggestions.concat(suggestions)
    end
    
    # Remove duplicate suggestions and sort by priority
    deduplicate_and_prioritize(index_suggestions)
  end

  private

  def group_queries_by_table
    queries.group_by do |query|
      parser = SqlParserService.new(query.sql_query)
      parser.primary_table
    end.reject { |table, _| table.nil? }
  end

  def analyze_table_queries(table_name, table_queries)
    suggestions = []
    
    # Analyze WHERE clause patterns
    where_column_frequency = analyze_where_patterns(table_queries)
    suggestions.concat(generate_where_index_suggestions(table_name, where_column_frequency))
    
    # Analyze ORDER BY patterns
    order_column_frequency = analyze_order_patterns(table_queries)
    suggestions.concat(generate_order_index_suggestions(table_name, order_column_frequency))
    
    # Analyze composite index opportunities
    composite_patterns = analyze_composite_patterns(table_queries)
    suggestions.concat(generate_composite_index_suggestions(table_name, composite_patterns))
    
    # Analyze foreign key patterns
    foreign_key_patterns = analyze_foreign_key_patterns(table_queries)
    suggestions.concat(generate_foreign_key_index_suggestions(table_name, foreign_key_patterns))
    
    suggestions
  end

  def analyze_where_patterns(table_queries)
    column_frequency = Hash.new(0)
    
    table_queries.each do |query|
      parser = SqlParserService.new(query.sql_query)
      next unless parser.valid?
      
      parser.where_columns.each do |column|
        # Clean column name (remove table prefix if present)
        clean_column = column.split('.').last
        column_frequency[clean_column] += 1
      end
    end
    
    column_frequency.select { |_, freq| freq >= frequency_threshold }
  end

  def analyze_order_patterns(table_queries)
    column_frequency = Hash.new(0)
    
    table_queries.each do |query|
      parser = SqlParserService.new(query.sql_query)
      next unless parser.valid?
      
      parser.order_by_columns.each do |column|
        clean_column = column.split('.').last
        column_frequency[clean_column] += 1
      end
    end
    
    column_frequency.select { |_, freq| freq >= frequency_threshold }
  end

  def analyze_composite_patterns(table_queries)
    pattern_frequency = Hash.new(0)
    
    table_queries.each do |query|
      parser = SqlParserService.new(query.sql_query)
      next unless parser.valid?
      
      where_columns = parser.where_columns.map { |col| col.split('.').last }
      
      # Look for queries with multiple WHERE conditions
      if where_columns.length > 1
        # Sort columns to create consistent pattern
        pattern = where_columns.sort.join(',')
        pattern_frequency[pattern] += 1
      end
    end
    
    pattern_frequency.select { |_, freq| freq >= frequency_threshold }
  end

  def analyze_foreign_key_patterns(table_queries)
    fk_frequency = Hash.new(0)
    
    table_queries.each do |query|
      parser = SqlParserService.new(query.sql_query)
      next unless parser.valid?
      
      parser.where_columns.each do |column|
        clean_column = column.split('.').last
        # Detect foreign key patterns (ending with _id)
        if clean_column.match?(/\w+_id$/)
          fk_frequency[clean_column] += 1
        end
      end
    end
    
    fk_frequency.select { |_, freq| freq >= frequency_threshold }
  end

  def generate_where_index_suggestions(table_name, column_frequency)
    suggestions = []
    
    column_frequency.each do |column, frequency|
      suggestions << {
        type: 'single_column_index',
        table_name: table_name,
        columns: [column],
        frequency: frequency,
        priority: calculate_priority(frequency),
        reason: 'Frequently used in WHERE clauses',
        sql: "CREATE INDEX idx_#{table_name}_#{column} ON #{table_name}(#{column});",
        impact: 'high',
        description: "Column '#{column}' is used in WHERE clauses #{frequency} times"
      }
    end
    
    suggestions
  end

  def generate_order_index_suggestions(table_name, column_frequency)
    suggestions = []
    
    column_frequency.each do |column, frequency|
      suggestions << {
        type: 'order_by_index',
        table_name: table_name,
        columns: [column],
        frequency: frequency,
        priority: calculate_priority(frequency),
        reason: 'Frequently used in ORDER BY clauses',
        sql: "CREATE INDEX idx_#{table_name}_#{column}_order ON #{table_name}(#{column});",
        impact: 'medium',
        description: "Column '#{column}' is used in ORDER BY clauses #{frequency} times"
      }
    end
    
    suggestions
  end

  def generate_composite_index_suggestions(table_name, pattern_frequency)
    suggestions = []
    
    pattern_frequency.each do |pattern, frequency|
      columns = pattern.split(',')
      column_list = columns.join(', ')
      index_name = "idx_#{table_name}_#{columns.join('_')}"
      
      suggestions << {
        type: 'composite_index',
        table_name: table_name,
        columns: columns,
        frequency: frequency,
        priority: calculate_priority(frequency, bonus: 1), # Composite indexes get priority bonus
        reason: 'Frequently used together in WHERE clauses',
        sql: "CREATE INDEX #{index_name} ON #{table_name}(#{column_list});",
        impact: 'high',
        description: "Columns '#{column_list}' are frequently used together #{frequency} times"
      }
    end
    
    suggestions
  end

  def generate_foreign_key_index_suggestions(table_name, fk_frequency)
    suggestions = []
    
    fk_frequency.each do |fk_column, frequency|
      suggestions << {
        type: 'foreign_key_index',
        table_name: table_name,
        columns: [fk_column],
        frequency: frequency,
        priority: calculate_priority(frequency, bonus: 2), # Foreign keys get high priority
        reason: 'Foreign key used in WHERE clauses',
        sql: "CREATE INDEX idx_#{table_name}_#{fk_column} ON #{table_name}(#{fk_column});",
        impact: 'high',
        description: "Foreign key '#{fk_column}' is used in WHERE clauses #{frequency} times"
      }
    end
    
    suggestions
  end

  def calculate_priority(frequency, bonus: 0)
    base_priority = case frequency
    when 0..2
      1
    when 3..5
      2
    when 6..10
      3
    when 11..14
      4
    else
      5
    end

    [base_priority + bonus, 5].min # Cap at 5
  end

  def deduplicate_and_prioritize(suggestions)
    # Group by table and columns to remove duplicates
    unique_suggestions = suggestions.group_by do |suggestion|
      [suggestion[:table_name], suggestion[:columns].sort]
    end.map do |_, grouped|
      # Keep the highest priority suggestion for each unique combination
      grouped.max_by { |s| s[:priority] }
    end
    
    # Sort by priority (highest first) and frequency
    unique_suggestions.sort_by { |s| [-s[:priority], -s[:frequency]] }
  end
end
