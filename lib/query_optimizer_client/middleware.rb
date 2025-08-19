# frozen_string_literal: true

module QueryOptimizerClient
  class Middleware
    def initialize(app, options = {})
      @app = app
      @options = default_options.merge(options)
      @client = QueryOptimizerClient.client
    end

    def call(env)
      return @app.call(env) unless should_monitor?(env)

      queries = []
      
      subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
        duration = (finish - start) * 1000
        
        next if skip_query?(payload, duration)
        
        queries << {
          sql: payload[:sql],
          duration_ms: duration.round(2)
        }
      end

      status, headers, response = @app.call(env)

      # Analyze queries asynchronously if we have enough
      if queries.length >= @options[:min_queries]
        analyze_queries_async(queries, extract_endpoint(env))
      end

      [status, headers, response]
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription) if subscription
    end

    private

    def default_options
      {
        min_queries: 3,
        min_duration: 10,
        skip_paths: ['/assets', '/health', '/api'],
        skip_methods: ['OPTIONS', 'HEAD'],
        async: true,
        job_class: 'QueryOptimizerClient::AnalysisJob'
      }
    end

    def should_monitor?(env)
      return false unless QueryOptimizerClient.enabled?
      
      request = Rack::Request.new(env)
      
      # Skip certain paths
      return false if @options[:skip_paths].any? { |path| request.path.start_with?(path) }
      
      # Skip certain methods
      return false if @options[:skip_methods].include?(request.request_method)
      
      true
    end

    def skip_query?(payload, duration)
      # Skip schema queries, cache queries, and very fast queries
      payload[:name] =~ /SCHEMA|CACHE/ || duration < @options[:min_duration]
    end

    def extract_endpoint(env)
      request = Rack::Request.new(env)
      "#{request.request_method} #{request.path}"
    end

    def analyze_queries_async(queries, endpoint)
      if @options[:async] && defined?(ActiveJob)
        job_class = @options[:job_class].constantize
        job_class.perform_later(queries, endpoint)
      else
        analyze_queries_sync(queries, endpoint)
      end
    rescue NameError
      # Fallback to sync if job class doesn't exist
      analyze_queries_sync(queries, endpoint)
    end

    def analyze_queries_sync(queries, endpoint)
      result = @client.analyze_queries(queries)
      
      if result&.dig('success')
        handle_analysis_result(result['data'], endpoint)
      end
    rescue => e
      QueryOptimizerClient.configuration.logger&.error("Query analysis failed: #{e.message}")
    end

    def handle_analysis_result(data, endpoint)
      score = data['summary']['optimization_score']
      
      # Log issues
      if data['n_plus_one']['detected']
        QueryOptimizerClient.configuration.logger&.warn(
          "N+1 queries detected on #{endpoint}: #{data['n_plus_one']['patterns'].length} patterns"
        )
      end
      
      data['slow_queries'].each do |query|
        QueryOptimizerClient.configuration.logger&.warn(
          "Slow query on #{endpoint} (#{query['duration_ms']}ms): #{query['sql'][0..100]}..."
        )
      end
      
      # Alert if score is low
      if score < 60
        QueryOptimizerClient.configuration.logger&.error(
          "CRITICAL: Low performance score (#{score}%) on #{endpoint}"
        )
      elsif score < 75
        QueryOptimizerClient.configuration.logger&.warn(
          "WARNING: Performance score (#{score}%) on #{endpoint}"
        )
      end
    end
  end
end
