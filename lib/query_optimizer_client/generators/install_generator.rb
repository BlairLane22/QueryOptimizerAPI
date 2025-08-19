# frozen_string_literal: true

require 'rails/generators'

module QueryOptimizerClient
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc "Install Query Optimizer Client"
      
      source_root File.expand_path('templates', __dir__)
      
      def create_initializer
        template 'initializer.rb', 'config/initializers/query_optimizer_client.rb'
      end
      
      def create_job
        template 'analysis_job.rb', 'app/jobs/query_optimizer_client/analysis_job.rb'
      end
      
      def add_environment_variables
        environment_template = <<~ENV
          # Query Optimizer Client Configuration
          # QUERY_OPTIMIZER_API_URL=http://localhost:3000/api/v1
          # QUERY_OPTIMIZER_API_KEY=your_api_key_here
          # QUERY_OPTIMIZER_ENABLED=true
          # QUERY_OPTIMIZER_THRESHOLD=80
        ENV
        
        append_to_file '.env.example', environment_template
        
        if File.exist?('.env')
          append_to_file '.env', environment_template
        else
          create_file '.env', environment_template
        end
      end
      
      def show_readme
        readme 'README'
      end
    end
  end
end
