# frozen_string_literal: true

module QueryOptimizerClient
  class AnalysisJob < ApplicationJob
    queue_as :default
    
    def perform(queries, endpoint = nil)
      return unless QueryOptimizerClient.enabled?
      
      result = QueryOptimizerClient.analyze_queries(queries)
      
      return unless result&.dig('success')
      
      data = result['data']
      score = data['summary']['optimization_score']
      
      # Log analysis results
      log_analysis_results(data, endpoint)
      
      # Store results (optional - implement based on your needs)
      store_analysis_results(data, endpoint) if respond_to?(:store_analysis_results, true)
      
      # Send alerts if performance is poor
      send_alerts(data, endpoint, score) if score < 70
      
    rescue => e
      Rails.logger.error "Query analysis failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
    end
    
    private
    
    def log_analysis_results(data, endpoint)
      endpoint_info = endpoint ? " on #{endpoint}" : ""
      
      Rails.logger.info "Query analysis completed#{endpoint_info}: Score #{data['summary']['optimization_score']}%, #{data['summary']['issues_found']} issues found"
      
      # Log N+1 queries
      if data['n_plus_one']['detected']
        Rails.logger.warn "N+1 queries detected#{endpoint_info}:"
        data['n_plus_one']['patterns'].each do |pattern|
          Rails.logger.warn "  - #{pattern['table']}.#{pattern['column']}: #{pattern['suggestion']}"
        end
      end
      
      # Log slow queries
      data['slow_queries'].each do |query|
        Rails.logger.warn "Slow query#{endpoint_info} (#{query['duration_ms']}ms): #{query['sql'][0..100]}..."
        query['suggestions'].each do |suggestion|
          Rails.logger.warn "  💡 #{suggestion}"
        end
      end
      
      # Log missing indexes
      data['missing_indexes'].each do |index|
        Rails.logger.info "Missing index suggestion#{endpoint_info}: #{index['sql']}"
      end
    end
    
    def send_alerts(data, endpoint, score)
      endpoint_info = endpoint ? " on #{endpoint}" : ""
      
      if score < 50
        Rails.logger.error "🚨 CRITICAL: Very low performance score (#{score}%)#{endpoint_info}"
        # Add your critical alerting logic here (Slack, email, etc.)
      elsif score < 70
        Rails.logger.warn "⚠️ WARNING: Low performance score (#{score}%)#{endpoint_info}"
        # Add your warning alerting logic here
      end
    end
    
    # Optional: Implement this method to store analysis results in your database
    # def store_analysis_results(data, endpoint)
    #   PerformanceAnalysis.create!(
    #     endpoint: endpoint,
    #     optimization_score: data['summary']['optimization_score'],
    #     issues_found: data['summary']['issues_found'],
    #     total_queries: data['summary']['total_queries'],
    #     analysis_data: data,
    #     analyzed_at: Time.current
    #   )
    # end
  end
end
