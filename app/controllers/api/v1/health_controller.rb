class Api::V1::HealthController < Api::V1::BaseController
  # Skip authentication for health checks
  skip_before_action :authenticate_api_key
  
  def show
    health_data = {
      status: 'ok',
      timestamp: Time.current.iso8601,
      version: '1.0.0',
      services: check_services
    }
    
    overall_status = health_data[:services].values.all? { |status| status == 'ok' } ? 'ok' : 'degraded'
    health_data[:status] = overall_status
    
    status_code = overall_status == 'ok' ? :ok : :service_unavailable
    
    render json: health_data, status: status_code
  end
  
  private
  
  def check_services
    services = {}
    
    # Database connectivity
    services[:database] = check_database
    
    # SQL Parser
    services[:sql_parser] = check_sql_parser
    
    # Analysis services
    services[:analysis_services] = check_analysis_services
    
    services
  end
  
  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    'ok'
  rescue => e
    Rails.logger.error "Database health check failed: #{e.message}"
    'error'
  end
  
  def check_sql_parser
    test_sql = "SELECT id FROM users WHERE email = 'test@example.com'"
    parser = SqlParserService.new(test_sql)
    
    if parser.valid? && parser.query_type == 'SELECT' && parser.primary_table == 'users'
      'ok'
    else
      'error'
    end
  rescue => e
    Rails.logger.error "SQL Parser health check failed: #{e.message}"
    'error'
  end
  
  def check_analysis_services
    # Test with a simple query analysis
    test_queries = [
      QueryAnalysis.new(
        sql_query: "SELECT * FROM users WHERE id = 1",
        duration_ms: 100,
        table_name: "users",
        query_type: "SELECT",
        analyzed_at: Time.current
      )
    ]
    
    # Test N+1 detector
    NPlusOneDetectorService.detect(test_queries)
    
    # Test slow query analyzer
    SlowQueryAnalyzerService.analyze(test_queries)
    
    # Test missing index detector
    MissingIndexDetectorService.detect(test_queries)
    
    'ok'
  rescue => e
    Rails.logger.error "Analysis services health check failed: #{e.message}"
    'error'
  end
end
