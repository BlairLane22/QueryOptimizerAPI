class Api::V1::AnalysisController < Api::V1::BaseController
  def analyze
    if params[:queries].nil?
      render_error('Missing required parameter: queries')
      return
    end

    queries_data = params[:queries]

    # Validate queries using the validator
    validation_errors = QueryDataValidator.validate_queries(queries_data)
    if validation_errors.any?
      render_error('Validation failed', :bad_request, errors: validation_errors)
      return
    end
    
    # Create QueryAnalysis records
    query_analyses = []
    queries_data.each do |query_data|
      begin
        analysis = create_query_analysis(query_data)
        query_analyses << analysis if analysis
      rescue => e
        Rails.logger.error "Error creating query analysis: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    if query_analyses.empty?
      render_error('No valid queries provided')
      return
    end

    # Run analysis
    begin
      analysis_results = perform_analysis(query_analyses)
    rescue => e
      Rails.logger.error "Error performing analysis: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render_error('Analysis failed')
      return
    end
    
    # Store optimization suggestions
    begin
      store_suggestions(query_analyses, analysis_results)
    rescue => e
      Rails.logger.error "Failed to store suggestions: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Continue without storing suggestions for now
    end
    
    # Format response
    response_data = format_analysis_response(analysis_results)
    
    render_success(response_data, message: "Analyzed #{query_analyses.length} queries")
  end
  
  def analyze_ci
    if params[:queries].nil?
      render_error('Missing required parameter: queries')
      return
    end

    queries_data = params[:queries]
    threshold_score = params[:threshold_score] || 70

    # Validate queries using the validator
    validation_errors = QueryDataValidator.validate_queries(queries_data)
    if validation_errors.any?
      render_error('Validation failed', :bad_request, errors: validation_errors)
      return
    end

    # Validate threshold score
    if threshold_score.present? && (!threshold_score.is_a?(Numeric) || threshold_score < 0 || threshold_score > 100)
      render_error('Threshold score must be a number between 0 and 100')
      return
    end
    
    # Create temporary QueryAnalysis records (don't persist for CI)
    query_analyses = []
    queries_data.each do |query_data|
      analysis = build_query_analysis(query_data)
      query_analyses << analysis if analysis&.valid?
    end
    
    if query_analyses.empty?
      render_error('No valid queries provided')
      return
    end
    
    # Run analysis
    analysis_results = perform_analysis(query_analyses)
    
    # Calculate CI score
    ci_results = calculate_ci_score(analysis_results, threshold_score)
    
    render_success(ci_results)
  end
  
  private
  
  def create_query_analysis(query_data)
    sql_query = query_data[:sql] || query_data['sql']
    duration_ms = query_data[:duration_ms] || query_data['duration_ms']

    if sql_query.blank?
      return nil
    end

    parser = SqlParserService.new(sql_query)

    # Ensure we have valid parsed data
    unless parser.valid?
      Rails.logger.error "Invalid SQL query: #{sql_query}"
      return nil
    end

    @current_app_profile.query_analyses.create!(
      sql_query: sql_query,
      duration_ms: duration_ms,
      table_name: parser.primary_table,
      query_type: parser.query_type,
      analyzed_at: Time.current,
      query_hash: parser.query_signature,
      parsed_data: {
        where_columns: parser.where_columns,
        order_by_columns: parser.order_by_columns,
        all_tables: parser.all_tables
      }
    )
  rescue => e
    Rails.logger.error "Failed to create query analysis: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    nil
  end
  
  def build_query_analysis(query_data)
    sql_query = query_data[:sql] || query_data['sql']
    duration_ms = query_data[:duration_ms] || query_data['duration_ms']
    
    return nil if sql_query.blank?
    
    parser = SqlParserService.new(sql_query)
    
    @current_app_profile.query_analyses.build(
      sql_query: sql_query,
      duration_ms: duration_ms,
      table_name: parser.primary_table,
      query_type: parser.query_type,
      analyzed_at: Time.current,
      query_hash: parser.query_signature,
      parsed_data: {
        where_columns: parser.where_columns,
        order_by_columns: parser.order_by_columns,
        all_tables: parser.all_tables
      }
    )
  rescue => e
    Rails.logger.error "Failed to build query analysis: #{e.message}"
    nil
  end
  
  def perform_analysis(query_analyses)
    results = {
      n_plus_one: [],
      slow_queries: [],
      missing_indexes: []
    }
    
    # N+1 Detection
    n_plus_one_patterns = NPlusOneDetectorService.detect(query_analyses)
    results[:n_plus_one] = n_plus_one_patterns
    
    # Slow Query Analysis
    slow_query_issues = SlowQueryAnalyzerService.analyze(query_analyses)
    results[:slow_queries] = slow_query_issues
    
    # Missing Index Detection
    index_suggestions = MissingIndexDetectorService.detect(query_analyses)
    results[:missing_indexes] = index_suggestions
    
    results
  end
  
  def store_suggestions(query_analyses, analysis_results)
    # Store N+1 suggestions
    analysis_results[:n_plus_one].each do |pattern|
      next unless pattern[:first_query]
      
      OptimizationSuggestion.create!(
        query_analysis: pattern[:first_query],
        suggestion_type: 'n_plus_one',
        title: pattern[:suggestion][:title],
        description: pattern[:suggestion][:description],
        sql_suggestion: pattern[:suggestion][:sql_suggestion],
        priority: severity_to_priority(pattern[:severity]),
        metadata: pattern.except(:first_query, :sample_queries)
      )
    end
    
    # Store slow query suggestions
    analysis_results[:slow_queries].each do |issue|
      issue[:suggestions].each do |suggestion|
        OptimizationSuggestion.create!(
          query_analysis: issue[:query_analysis],
          suggestion_type: 'slow_query',
          title: suggestion[:title],
          description: suggestion[:description],
          sql_suggestion: suggestion[:sql_example],
          priority: priority_to_number(suggestion[:priority]),
          metadata: suggestion.except(:title, :description, :sql_example)
        )
      end
    end
    
    # Store index suggestions (create a representative query analysis if needed)
    analysis_results[:missing_indexes].each do |suggestion|
      # Find a representative query for this table
      representative_query = query_analyses.find { |qa| qa.table_name == suggestion[:table_name] }
      next unless representative_query
      
      OptimizationSuggestion.create!(
        query_analysis: representative_query,
        suggestion_type: 'missing_index',
        title: "Add index on #{suggestion[:table_name]}(#{suggestion[:columns].join(', ')})",
        description: suggestion[:description],
        sql_suggestion: suggestion[:sql],
        priority: suggestion[:priority],
        metadata: suggestion.except(:sql, :description)
      )
    end
  rescue => e
    Rails.logger.error "Failed to store suggestions: #{e.message}"
  end
  
  def format_analysis_response(results)
    {
      n_plus_one: {
        detected: results[:n_plus_one].any?,
        patterns: results[:n_plus_one].map { |pattern| format_n_plus_one_pattern(pattern) }
      },
      slow_queries: results[:slow_queries].map { |issue| format_slow_query_issue(issue) },
      missing_indexes: results[:missing_indexes].map { |suggestion| format_index_suggestion(suggestion) },
      summary: {
        total_issues: results[:n_plus_one].length + results[:slow_queries].length,
        index_suggestions: results[:missing_indexes].length,
        severity_breakdown: calculate_severity_breakdown(results)
      }
    }
  end
  
  def format_n_plus_one_pattern(pattern)
    {
      table: pattern[:table_name],
      column: pattern[:column_name],
      query_count: pattern[:query_count],
      severity: pattern[:severity],
      suggestion: pattern[:suggestion][:rails_suggestion],
      example_code: pattern[:suggestion][:example_code]
    }
  end
  
  def format_slow_query_issue(issue)
    {
      sql: issue[:query_analysis].sql_query,
      duration_ms: issue[:duration_ms],
      severity: issue[:severity],
      table: issue[:table_name],
      suggestions: issue[:suggestions].map { |s| s.slice(:title, :description, :recommendation) }
    }
  end
  
  def format_index_suggestion(suggestion)
    {
      table: suggestion[:table_name],
      columns: suggestion[:columns],
      type: suggestion[:type],
      reason: suggestion[:reason],
      sql: suggestion[:sql],
      priority: suggestion[:priority],
      impact: suggestion[:impact]
    }
  end
  
  def calculate_ci_score(results, threshold)
    total_issues = results[:n_plus_one].length + results[:slow_queries].length
    critical_issues = results[:n_plus_one].count { |p| p[:severity] == 'critical' } +
                     results[:slow_queries].count { |i| i[:severity] == 'critical' }
    
    # Calculate score (100 = perfect, 0 = terrible)
    score = 100
    score -= total_issues * 5  # -5 points per issue
    score -= critical_issues * 15  # Additional -15 points for critical issues
    score = [score, 0].max  # Don't go below 0
    
    {
      score: score,
      passed: score >= threshold,
      threshold: threshold,
      issues: {
        total: total_issues,
        critical: critical_issues,
        n_plus_one: results[:n_plus_one].length,
        slow_queries: results[:slow_queries].length
      },
      recommendations: results[:missing_indexes].length
    }
  end
  
  def severity_to_priority(severity)
    case severity
    when 'low' then 1
    when 'medium' then 2
    when 'high' then 3
    when 'critical' then 4
    else 2
    end
  end
  
  def priority_to_number(priority)
    case priority
    when 'low' then 1
    when 'medium' then 2
    when 'high' then 3
    when 'critical' then 4
    else 2
    end
  end
  
  def calculate_severity_breakdown(results)
    breakdown = { low: 0, medium: 0, high: 0, critical: 0 }
    
    results[:n_plus_one].each { |p| breakdown[p[:severity].to_sym] += 1 }
    results[:slow_queries].each { |i| breakdown[i[:severity].to_sym] += 1 }
    
    breakdown
  end
end
