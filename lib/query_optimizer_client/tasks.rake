# frozen_string_literal: true

namespace :query_optimizer do
  desc "Check configuration and connectivity"
  task check: :environment do
    puts "🔍 Query Optimizer Client Configuration Check"
    puts "=" * 50
    
    config = QueryOptimizerClient.configuration
    
    puts "API URL: #{config.api_url}"
    puts "API Key: #{config.api_key ? '[SET]' : '[NOT SET]'}"
    puts "Enabled: #{config.enabled?}"
    puts "Timeout: #{config.timeout}s"
    puts "Retries: #{config.retries}"
    puts "Batch Size: #{config.batch_size}"
    puts "Default Threshold: #{config.default_threshold}%"
    
    if config.enabled?
      puts "\n🔗 Testing API connectivity..."
      
      begin
        result = QueryOptimizerClient.client.health_check
        
        if result&.dig('status') == 'ok'
          puts "✅ API connection successful"
          puts "   Version: #{result['version']}"
          puts "   Services: #{result['services']}"
        else
          puts "⚠️  API responded but status is: #{result&.dig('status')}"
        end
      rescue QueryOptimizerClient::AuthenticationError
        puts "❌ Authentication failed - check your API key"
      rescue QueryOptimizerClient::APIError => e
        puts "❌ API error: #{e.message}"
      rescue => e
        puts "❌ Connection failed: #{e.message}"
      end
    else
      puts "\n⚠️  Client is disabled or not configured"
    end
  end

  desc "Analyze sample queries"
  task analyze: :environment do
    unless QueryOptimizerClient.enabled?
      puts "❌ Query Optimizer Client is not enabled"
      exit 1
    end

    puts "🔍 Analyzing sample queries..."
    
    # Collect some sample queries from your application
    queries = collect_sample_queries
    
    if queries.empty?
      puts "⚠️  No queries to analyze"
      exit 0
    end
    
    puts "Collected #{queries.length} queries"
    
    begin
      result = QueryOptimizerClient.analyze_queries(queries)
      
      if result&.dig('success')
        display_analysis_results(result['data'])
      else
        puts "❌ Analysis failed: #{result&.dig('error')}"
      end
    rescue => e
      puts "❌ Error during analysis: #{e.message}"
    end
  end

  desc "Run CI performance check"
  task :ci, [:threshold] => :environment do |t, args|
    threshold = args[:threshold]&.to_i || QueryOptimizerClient.configuration.default_threshold
    
    unless QueryOptimizerClient.enabled?
      puts "⚠️  Query Optimizer Client is disabled, skipping check"
      exit 0
    end

    puts "🔍 Running CI performance check (threshold: #{threshold}%)"
    
    queries = collect_sample_queries
    
    if queries.empty?
      puts "⚠️  No queries to analyze, passing by default"
      exit 0
    end
    
    begin
      result = QueryOptimizerClient.analyze_for_ci(queries, threshold: threshold)
      
      if result&.dig('data', 'passed')
        puts "✅ Performance check PASSED (Score: #{result['data']['score']}%)"
        exit 0
      else
        puts "❌ Performance check FAILED (Score: #{result['data']['score']}%)"
        
        if result['data']['recommendations']
          puts "\n💡 Recommendations:"
          result['data']['recommendations'].each do |rec|
            puts "  - #{rec}"
          end
        end
        
        exit 1
      end
    rescue => e
      puts "❌ CI check failed: #{e.message}"
      exit 1
    end
  end

  desc "Generate API key"
  task :generate_key, [:app_name] => :environment do |t, args|
    app_name = args[:app_name] || "Rails App #{Time.current.strftime('%Y%m%d')}"
    
    puts "🔑 Generating API key for: #{app_name}"
    
    begin
      result = QueryOptimizerClient.client.create_api_key(app_name)
      
      if result&.dig('success')
        puts "✅ API key created successfully!"
        puts "App Name: #{result['data']['app_name']}"
        puts "API Key: #{result['data']['api_key']}"
        puts "\nAdd this to your environment:"
        puts "QUERY_OPTIMIZER_API_KEY=#{result['data']['api_key']}"
      else
        puts "❌ Failed to create API key: #{result&.dig('error')}"
      end
    rescue => e
      puts "❌ Error creating API key: #{e.message}"
    end
  end

  private

  def collect_sample_queries
    queries = []
    
    # Try to collect some real queries from your models
    if defined?(ActiveRecord::Base)
      subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
        duration = (finish - start) * 1000
        next if payload[:name] =~ /SCHEMA|CACHE/ || duration < 1
        
        queries << {
          sql: payload[:sql],
          duration_ms: duration.round(2)
        }
      end
      
      # Execute some common queries
      begin
        if defined?(User) && User.respond_to?(:limit)
          User.limit(5).to_a
        end
        
        if defined?(ApplicationRecord)
          ApplicationRecord.descendants.first(3).each do |model|
            next if model.abstract_class?
            model.limit(3).to_a rescue nil
          end
        end
      rescue => e
        # Ignore errors, we're just trying to collect sample queries
      ensure
        ActiveSupport::Notifications.unsubscribe(subscription) if subscription
      end
    end
    
    # Add some default queries if we couldn't collect any
    if queries.empty?
      queries = [
        { sql: "SELECT * FROM users WHERE active = true", duration_ms: 45 },
        { sql: "SELECT * FROM posts WHERE created_at > '2024-01-01'", duration_ms: 120 }
      ]
    end
    
    queries
  end

  def display_analysis_results(data)
    puts "\n📊 Analysis Results"
    puts "=" * 30
    puts "Overall Score: #{data['summary']['optimization_score']}/100"
    puts "Issues Found: #{data['summary']['issues_found']}"
    puts "Queries Analyzed: #{data['summary']['total_queries']}"
    
    if data['n_plus_one']['detected']
      puts "\n🔍 N+1 Query Issues:"
      data['n_plus_one']['patterns'].each do |pattern|
        puts "  ⚠️  #{pattern['table']}.#{pattern['column']}"
        puts "     💡 #{pattern['suggestion']}"
      end
    end
    
    unless data['slow_queries'].empty?
      puts "\n🐌 Slow Queries:"
      data['slow_queries'].each do |query|
        puts "  ⚠️  #{query['duration_ms']}ms: #{query['sql'][0..80]}..."
        query['suggestions'].each do |suggestion|
          puts "     💡 #{suggestion}"
        end
      end
    end
    
    unless data['missing_indexes'].empty?
      puts "\n📊 Missing Indexes:"
      data['missing_indexes'].each do |index|
        puts "  💡 #{index['sql']}"
      end
    end
    
    if data['summary']['optimization_score'] >= 80
      puts "\n✅ Great job! Your queries are well optimized."
    elsif data['summary']['optimization_score'] >= 60
      puts "\n⚠️  Some optimization opportunities found."
    else
      puts "\n🚨 Significant performance issues detected."
    end
  end
end
