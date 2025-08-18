class SlowQueryAnalyzerService
  attr_reader :queries, :slow_threshold, :very_slow_threshold, :critical_threshold

  def initialize(queries, slow_threshold: 200, very_slow_threshold: 1000, critical_threshold: 5000)
    @queries = Array(queries)
    @slow_threshold = slow_threshold
    @very_slow_threshold = very_slow_threshold
    @critical_threshold = critical_threshold
  end

  def self.analyze(queries, **options)
    new(queries, **options).analyze
  end

  def analyze
    slow_query_issues = []

    queries.each do |query|
      next unless query.duration_ms && query.duration_ms > slow_threshold

      issue = analyze_slow_query(query)
      slow_query_issues << issue if issue
    end

    slow_query_issues
  end

  private

  def analyze_slow_query(query)
    parser = SqlParserService.new(query.sql_query)
    return nil unless parser.valid?

    severity = calculate_severity(query.duration_ms)
    complexity_issues = analyze_query_complexity(parser)
    optimization_suggestions = generate_optimization_suggestions(parser, query, complexity_issues)

    {
      type: 'slow_query',
      query_analysis: query,
      duration_ms: query.duration_ms,
      severity: severity,
      table_name: parser.primary_table,
      query_type: parser.query_type,
      complexity_issues: complexity_issues,
      suggestions: optimization_suggestions,
      pattern_signature: parser.query_signature
    }
  end

  def calculate_severity(duration_ms)
    case duration_ms
    when 0...slow_threshold
      'normal'
    when slow_threshold...very_slow_threshold
      'slow'
    when very_slow_threshold...critical_threshold
      'very_slow'
    else
      'critical'
    end
  end

  def analyze_query_complexity(parser)
    issues = []

    # Check for SELECT * queries
    if parser.sql_query.match?(/SELECT\s+\*/i)
      issues << {
        type: 'select_star',
        description: 'Using SELECT * can be inefficient',
        impact: 'medium'
      }
    end

    # Check for missing WHERE clause on large tables
    if parser.query_type == 'SELECT' && parser.where_conditions.empty?
      issues << {
        type: 'no_where_clause',
        description: 'Query without WHERE clause may scan entire table',
        impact: 'high'
      }
    end

    # Check for complex WHERE conditions
    where_conditions = parser.where_conditions
    if where_conditions.length > 5
      issues << {
        type: 'complex_where',
        description: 'Query has many WHERE conditions which may be inefficient',
        impact: 'medium'
      }
    end

    # Check for function calls in WHERE clause
    if parser.sql_query.match?(/WHERE.*\w+\(/i)
      issues << {
        type: 'function_in_where',
        description: 'Function calls in WHERE clause prevent index usage',
        impact: 'high'
      }
    end

    # Check for LIKE with leading wildcard
    if parser.sql_query.match?(/LIKE\s+['"]%/i)
      issues << {
        type: 'leading_wildcard_like',
        description: 'LIKE with leading wildcard cannot use indexes efficiently',
        impact: 'high'
      }
    end

    # Check for OR conditions
    if parser.sql_query.match?(/\bOR\b/i)
      issues << {
        type: 'or_conditions',
        description: 'OR conditions can prevent efficient index usage',
        impact: 'medium'
      }
    end

    # Check for subqueries
    if parser.sql_query.match?(/\(\s*SELECT/i)
      issues << {
        type: 'subquery',
        description: 'Subqueries may be less efficient than JOINs',
        impact: 'medium'
      }
    end

    issues
  end

  def generate_optimization_suggestions(parser, query, complexity_issues)
    suggestions = []

    # Duration-based suggestions
    if query.duration_ms > critical_threshold
      suggestions << {
        title: 'Critical Performance Issue',
        description: "Query takes #{query.duration_ms}ms which is extremely slow",
        priority: 'critical',
        recommendation: 'Immediate optimization required - consider query rewrite, indexing, or caching'
      }
    elsif query.duration_ms > very_slow_threshold
      suggestions << {
        title: 'Very Slow Query',
        description: "Query takes #{query.duration_ms}ms which significantly impacts performance",
        priority: 'high',
        recommendation: 'High priority optimization needed'
      }
    elsif query.duration_ms > slow_threshold
      suggestions << {
        title: 'Slow Query',
        description: "Query takes #{query.duration_ms}ms which may impact user experience",
        priority: 'medium',
        recommendation: 'Consider optimization when possible'
      }
    end

    # Complexity-based suggestions
    complexity_issues.each do |issue|
      case issue[:type]
      when 'select_star'
        suggestions << {
          title: 'Avoid SELECT *',
          description: 'SELECT * retrieves all columns, including unnecessary ones',
          priority: 'medium',
          recommendation: 'Specify only the columns you need: SELECT id, name, email FROM users',
          sql_example: parser.sql_query.gsub(/SELECT\s+\*/i, 'SELECT id, name, created_at')
        }
      when 'no_where_clause'
        suggestions << {
          title: 'Add WHERE clause',
          description: 'Queries without WHERE clauses scan entire tables',
          priority: 'high',
          recommendation: 'Add appropriate WHERE conditions to limit the result set',
          sql_example: "#{parser.sql_query.chomp} WHERE created_at > '2023-01-01'"
        }
      when 'function_in_where'
        suggestions << {
          title: 'Avoid functions in WHERE clause',
          description: 'Functions in WHERE prevent index usage',
          priority: 'high',
          recommendation: 'Move function calls out of WHERE or create functional indexes'
        }
      when 'leading_wildcard_like'
        suggestions << {
          title: 'Optimize LIKE patterns',
          description: 'Leading wildcards in LIKE prevent index usage',
          priority: 'high',
          recommendation: 'Use full-text search or avoid leading wildcards when possible'
        }
      when 'or_conditions'
        suggestions << {
          title: 'Consider alternatives to OR',
          description: 'OR conditions can prevent efficient index usage',
          priority: 'medium',
          recommendation: 'Consider using UNION or IN clauses instead of OR'
        }
      when 'subquery'
        suggestions << {
          title: 'Consider JOIN instead of subquery',
          description: 'JOINs are often more efficient than subqueries',
          priority: 'medium',
          recommendation: 'Rewrite subqueries as JOINs when possible'
        }
      end
    end

    # Index suggestions based on WHERE conditions
    where_columns = parser.where_columns
    if where_columns.any?
      suggestions << {
        title: 'Consider adding indexes',
        description: "Query filters on columns: #{where_columns.join(', ')}",
        priority: 'medium',
        recommendation: "Consider adding indexes on frequently queried columns",
        sql_example: where_columns.map { |col| "CREATE INDEX idx_#{parser.primary_table}_#{col} ON #{parser.primary_table}(#{col});" }.join("\n")
      }
    end

    suggestions
  end
end
