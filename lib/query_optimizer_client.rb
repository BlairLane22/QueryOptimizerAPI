# frozen_string_literal: true

require_relative "query_optimizer_client/version"
require_relative "query_optimizer_client/client"
require_relative "query_optimizer_client/configuration"
require_relative "query_optimizer_client/middleware"
require_relative "query_optimizer_client/railtie" if defined?(Rails)

module QueryOptimizerClient
  class Error < StandardError; end
  class APIError < Error; end
  class AuthenticationError < Error; end
  class RateLimitError < Error; end
  class ValidationError < Error; end

  class << self
    attr_accessor :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  def self.client
    @client ||= Client.new(configuration)
  end

  def self.analyze_queries(queries)
    client.analyze_queries(queries)
  end

  def self.analyze_for_ci(queries, threshold: 80)
    client.analyze_for_ci(queries, threshold: threshold)
  end

  def self.enabled?
    configuration.enabled?
  end

  def self.reset!
    @configuration = nil
    @client = nil
  end
end
