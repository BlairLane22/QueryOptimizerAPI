# frozen_string_literal: true

require 'httparty'
require 'json'

module QueryOptimizerClient
  class Client
    include HTTParty

    def initialize(config)
      @config = config
      @config.validate!
      
      self.class.base_uri(@config.api_url)
      self.class.default_timeout(@config.timeout)
    end

    def analyze_queries(queries)
      return nil unless @config.enabled?
      
      validate_queries!(queries)
      
      with_retry do
        response = self.class.post('/analyze',
          headers: headers,
          body: { queries: format_queries(queries) }.to_json
        )
        
        handle_response(response)
      end
    end

    def analyze_for_ci(queries, threshold: nil)
      return { 'data' => { 'passed' => true, 'score' => 100 } } unless @config.enabled?
      
      threshold ||= @config.default_threshold
      validate_queries!(queries)
      validate_threshold!(threshold)
      
      with_retry do
        response = self.class.post('/analyze_ci',
          headers: headers,
          body: { 
            queries: format_queries(queries),
            threshold_score: threshold 
          }.to_json
        )
        
        handle_response(response)
      end
    end

    def health_check
      response = self.class.get('/health', headers: basic_headers)
      handle_response(response)
    end

    def create_api_key(app_name)
      response = self.class.post('/api_keys',
        headers: basic_headers,
        body: { app_name: app_name }.to_json
      )
      
      handle_response(response)
    end

    private

    def headers
      basic_headers.merge('X-API-Key' => @config.api_key)
    end

    def basic_headers
      { 'Content-Type' => 'application/json' }
    end

    def format_queries(queries)
      queries.map do |query|
        {
          sql: extract_sql(query),
          duration_ms: extract_duration(query)
        }.compact
      end
    end

    def extract_sql(query)
      case query
      when Hash
        query[:sql] || query['sql']
      when String
        query
      else
        query.to_s
      end
    end

    def extract_duration(query)
      return nil unless query.is_a?(Hash)
      
      duration = query[:duration_ms] || query['duration_ms']
      duration&.to_f&.round(2)
    end

    def validate_queries!(queries)
      raise ValidationError, "Queries must be an array" unless queries.is_a?(Array)
      raise ValidationError, "At least one query is required" if queries.empty?
      raise ValidationError, "Maximum #{@config.batch_size} queries allowed" if queries.length > @config.batch_size
      
      queries.each_with_index do |query, index|
        sql = extract_sql(query)
        raise ValidationError, "Query #{index + 1}: SQL is required" if sql.blank?
        raise ValidationError, "Query #{index + 1}: SQL too long (max 10000 chars)" if sql.length > 10000
      end
    end

    def validate_threshold!(threshold)
      unless threshold.is_a?(Numeric) && threshold >= 0 && threshold <= 100
        raise ValidationError, "Threshold must be a number between 0 and 100"
      end
    end

    def handle_response(response)
      case response.code
      when 200
        JSON.parse(response.body)
      when 400
        raise ValidationError, parse_error_message(response)
      when 401
        raise AuthenticationError, "Invalid API key"
      when 429
        raise RateLimitError, "Rate limit exceeded"
      when 500..599
        raise APIError, "Server error: #{response.code}"
      else
        raise APIError, "Unexpected response: #{response.code}"
      end
    rescue JSON::ParserError => e
      raise APIError, "Invalid JSON response: #{e.message}"
    end

    def parse_error_message(response)
      body = JSON.parse(response.body)
      body['error'] || body['errors']&.join(', ') || 'Unknown error'
    rescue JSON::ParserError
      "HTTP #{response.code}: #{response.body}"
    end

    def with_retry(&block)
      retries = 0
      
      begin
        yield
      rescue RateLimitError => e
        if @config.rate_limit_retry && retries < @config.retries
          wait_time = 2 ** retries
          @config.logger&.warn("Rate limited, waiting #{wait_time} seconds...")
          sleep(wait_time)
          retries += 1
          retry
        else
          raise e
        end
      rescue Net::TimeoutError, Errno::ECONNREFUSED => e
        if retries < @config.retries
          wait_time = 2 ** retries
          @config.logger&.warn("Connection error, retrying in #{wait_time} seconds...")
          sleep(wait_time)
          retries += 1
          retry
        else
          raise APIError, "Connection failed after #{@config.retries} retries: #{e.message}"
        end
      end
    end
  end
end
