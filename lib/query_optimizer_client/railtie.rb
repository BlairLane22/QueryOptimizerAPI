# frozen_string_literal: true

require 'rails/railtie'

module QueryOptimizerClient
  class Railtie < Rails::Railtie
    railtie_name :query_optimizer_client

    config.query_optimizer_client = ActiveSupport::OrderedOptions.new

    initializer "query_optimizer_client.configure" do |app|
      QueryOptimizerClient.configure do |config|
        # Set Rails logger
        config.logger = Rails.logger
        
        # Apply any configuration from Rails config
        app.config.query_optimizer_client.each do |key, value|
          config.public_send("#{key}=", value) if config.respond_to?("#{key}=")
        end
      end
    end

    initializer "query_optimizer_client.middleware" do |app|
      if QueryOptimizerClient.configuration.enabled?
        app.config.middleware.use QueryOptimizerClient::Middleware
      end
    end

    rake_tasks do
      load "query_optimizer_client/tasks.rake"
    end

    generators do
      require "query_optimizer_client/generators/install_generator"
    end
  end
end
