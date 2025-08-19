# frozen_string_literal: true

module QueryOptimizerClient
  class Configuration
    attr_accessor :api_url, :api_key, :enabled, :timeout, :retries, :logger,
                  :rate_limit_retry, :default_threshold, :batch_size

    def initialize
      @api_url = ENV.fetch('QUERY_OPTIMIZER_API_URL', 'http://localhost:3000/api/v1')
      @api_key = ENV['QUERY_OPTIMIZER_API_KEY']
      @enabled = ENV.fetch('QUERY_OPTIMIZER_ENABLED', 'false') == 'true'
      @timeout = ENV.fetch('QUERY_OPTIMIZER_TIMEOUT', '30').to_i
      @retries = ENV.fetch('QUERY_OPTIMIZER_RETRIES', '3').to_i
      @rate_limit_retry = ENV.fetch('QUERY_OPTIMIZER_RATE_LIMIT_RETRY', 'true') == 'true'
      @default_threshold = ENV.fetch('QUERY_OPTIMIZER_THRESHOLD', '80').to_i
      @batch_size = ENV.fetch('QUERY_OPTIMIZER_BATCH_SIZE', '50').to_i
      @logger = defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
    end

    def enabled?
      @enabled && @api_key.present?
    end

    def valid?
      api_key.present? && api_url.present?
    end

    def validate!
      raise ValidationError, "API key is required" unless api_key.present?
      raise ValidationError, "API URL is required" unless api_url.present?
      raise ValidationError, "Invalid API URL format" unless valid_url?(api_url)
    end

    private

    def valid_url?(url)
      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
    end
  end
end
