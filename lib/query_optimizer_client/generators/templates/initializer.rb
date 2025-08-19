# frozen_string_literal: true

QueryOptimizerClient.configure do |config|
  # API Configuration
  config.api_url = ENV.fetch('QUERY_OPTIMIZER_API_URL', 'http://localhost:3000/api/v1')
  config.api_key = ENV['QUERY_OPTIMIZER_API_KEY']
  config.enabled = ENV.fetch('QUERY_OPTIMIZER_ENABLED', 'false') == 'true'
  
  # Request Configuration
  config.timeout = ENV.fetch('QUERY_OPTIMIZER_TIMEOUT', '30').to_i
  config.retries = ENV.fetch('QUERY_OPTIMIZER_RETRIES', '3').to_i
  config.batch_size = ENV.fetch('QUERY_OPTIMIZER_BATCH_SIZE', '50').to_i
  
  # Analysis Configuration
  config.default_threshold = ENV.fetch('QUERY_OPTIMIZER_THRESHOLD', '80').to_i
  config.rate_limit_retry = ENV.fetch('QUERY_OPTIMIZER_RATE_LIMIT_RETRY', 'true') == 'true'
  
  # Logging
  config.logger = Rails.logger
end

# Optional: Configure Rails-specific settings
Rails.application.configure do
  # Middleware configuration
  config.query_optimizer_client.min_queries = 3
  config.query_optimizer_client.min_duration = 10
  config.query_optimizer_client.skip_paths = ['/assets', '/health', '/api']
  config.query_optimizer_client.async = true
  config.query_optimizer_client.job_class = 'QueryOptimizerClient::AnalysisJob'
end
