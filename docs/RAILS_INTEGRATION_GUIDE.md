# Rails Integration Guide

Complete guide for integrating the Query Optimizer API into your Rails applications.

## Table of Contents

1. [Setup and Configuration](#setup-and-configuration)
2. [Basic Integration](#basic-integration)
3. [Advanced Usage](#advanced-usage)
4. [Performance Monitoring](#performance-monitoring)
5. [CI/CD Integration](#cicd-integration)
6. [Best Practices](#best-practices)

## Setup and Configuration

### 1. Install Required Gems

Add to your Gemfile:

```ruby
# For HTTP requests to the API
gem 'httparty'
# Or use built-in Net::HTTP (no additional gem needed)

# For environment variables
gem 'dotenv-rails', groups: [:development, :test]
```

### 2. Environment Configuration

Create a `.env` file:

```bash
# .env
QUERY_OPTIMIZER_API_URL=http://localhost:3000/api/v1
QUERY_OPTIMIZER_API_KEY=your_api_key_here
QUERY_OPTIMIZER_ENABLED=true
QUERY_OPTIMIZER_THRESHOLD=80
```

### 3. Configuration Class

```ruby
# config/initializers/query_optimizer.rb
class QueryOptimizerConfig
  def self.enabled?
    ENV['QUERY_OPTIMIZER_ENABLED'] == 'true'
  end
  
  def self.api_url
    ENV['QUERY_OPTIMIZER_API_URL'] || 'http://localhost:3000/api/v1'
  end
  
  def self.api_key
    ENV['QUERY_OPTIMIZER_API_KEY']
  end
  
  def self.threshold
    ENV['QUERY_OPTIMIZER_THRESHOLD']&.to_i || 80
  end
end
```

## Basic Integration

### 1. Query Optimizer Service

```ruby
# app/services/query_optimizer_service.rb
class QueryOptimizerService
  include HTTParty
  
  base_uri QueryOptimizerConfig.api_url
  
  def initialize
    @api_key = QueryOptimizerConfig.api_key
    raise 'Query Optimizer API key not configured' unless @api_key
  end
  
  def analyze_queries(queries)
    return unless QueryOptimizerConfig.enabled?
    
    response = self.class.post('/analyze',
      headers: headers,
      body: { queries: format_queries(queries) }.to_json
    )
    
    handle_response(response)
  end
  
  def check_ci_quality(queries, threshold = nil)
    return true unless QueryOptimizerConfig.enabled?
    
    threshold ||= QueryOptimizerConfig.threshold
    
    response = self.class.post('/analyze_ci',
      headers: headers,
      body: { 
        queries: format_queries(queries),
        threshold_score: threshold 
      }.to_json
    )
    
    result = handle_response(response)
    result&.dig('data', 'passed') || false
  end
  
  private
  
  def headers
    {
      'Content-Type' => 'application/json',
      'X-API-Key' => @api_key
    }
  end
  
  def format_queries(queries)
    queries.map do |query|
      {
        sql: query[:sql] || query['sql'],
        duration_ms: query[:duration_ms] || query['duration_ms']
      }
    end
  end
  
  def handle_response(response)
    case response.code
    when 200
      JSON.parse(response.body)
    when 401
      Rails.logger.error "Query Optimizer: Invalid API key"
      nil
    when 429
      Rails.logger.warn "Query Optimizer: Rate limit exceeded"
      nil
    else
      Rails.logger.error "Query Optimizer: API error #{response.code}: #{response.body}"
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error "Query Optimizer: Invalid JSON response: #{e.message}"
    nil
  end
end
```

### 2. Query Collection Middleware

```ruby
# app/middleware/query_collector.rb
class QueryCollector
  def initialize(app)
    @app = app
  end
  
  def call(env)
    return @app.call(env) unless QueryOptimizerConfig.enabled?
    
    queries = []
    
    # Subscribe to SQL queries
    subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
      duration = (finish - start) * 1000 # Convert to milliseconds
      
      # Skip schema queries and very fast queries
      next if payload[:name] =~ /SCHEMA|CACHE/ || duration < 10
      
      queries << {
        sql: payload[:sql],
        duration_ms: duration.round(2)
      }
    end
    
    status, headers, response = @app.call(env)
    
    # Analyze queries after request completes
    analyze_queries_async(queries) if queries.any?
    
    [status, headers, response]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end
  
  private
  
  def analyze_queries_async(queries)
    # Use background job to avoid blocking the request
    QueryAnalysisJob.perform_later(queries)
  end
end

# Add to config/application.rb
config.middleware.use QueryCollector
```

### 3. Background Job for Analysis

```ruby
# app/jobs/query_analysis_job.rb
class QueryAnalysisJob < ApplicationJob
  queue_as :default
  
  def perform(queries)
    optimizer = QueryOptimizerService.new
    result = optimizer.analyze_queries(queries)
    
    return unless result&.dig('success')
    
    data = result['data']
    
    # Log N+1 queries
    if data['n_plus_one']['detected']
      Rails.logger.warn "N+1 Queries Detected:"
      data['n_plus_one']['patterns'].each do |pattern|
        Rails.logger.warn "  - #{pattern['table']}.#{pattern['column']}: #{pattern['suggestion']}"
      end
    end
    
    # Log slow queries
    data['slow_queries'].each do |query|
      Rails.logger.warn "Slow Query (#{query['duration_ms']}ms): #{query['sql']}"
      query['suggestions'].each do |suggestion|
        Rails.logger.warn "  - #{suggestion}"
      end
    end
    
    # Log missing indexes
    data['missing_indexes'].each do |index|
      Rails.logger.info "Missing Index Suggestion: #{index['sql']}"
    end
    
    # Store results for dashboard (optional)
    QueryOptimizationResult.create!(
      optimization_score: data['summary']['optimization_score'],
      issues_found: data['summary']['issues_found'],
      total_queries: data['summary']['total_queries'],
      analysis_data: data,
      analyzed_at: Time.current
    )
  end
end
```

## Advanced Usage

### 1. Custom Query Analysis

```ruby
# app/services/custom_query_analyzer.rb
class CustomQueryAnalyzer
  def initialize
    @optimizer = QueryOptimizerService.new
  end
  
  def analyze_model_queries(model_class)
    queries = collect_model_queries(model_class)
    result = @optimizer.analyze_queries(queries)
    
    return unless result&.dig('success')
    
    generate_model_report(model_class, result['data'])
  end
  
  def analyze_controller_action(controller, action)
    queries = []
    
    # Collect queries during a test request
    subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
      queries << {
        sql: payload[:sql],
        duration_ms: ((finish - start) * 1000).round(2)
      }
    end
    
    # Simulate the controller action
    simulate_controller_action(controller, action)
    
    result = @optimizer.analyze_queries(queries)
    generate_action_report(controller, action, result['data']) if result&.dig('success')
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end
  
  private
  
  def collect_model_queries(model_class)
    # Generate common queries for the model
    [
      { sql: model_class.all.to_sql, duration_ms: 50 },
      { sql: model_class.where(id: 1).to_sql, duration_ms: 25 },
      { sql: model_class.includes(:associations).to_sql, duration_ms: 100 }
    ]
  end
  
  def generate_model_report(model_class, data)
    puts "\n=== Query Analysis Report for #{model_class.name} ==="
    puts "Optimization Score: #{data['summary']['optimization_score']}/100"
    puts "Issues Found: #{data['summary']['issues_found']}"
    
    if data['n_plus_one']['detected']
      puts "\nN+1 Query Issues:"
      data['n_plus_one']['patterns'].each do |pattern|
        puts "  - #{pattern['suggestion']}"
      end
    end
    
    unless data['missing_indexes'].empty?
      puts "\nMissing Index Suggestions:"
      data['missing_indexes'].each do |index|
        puts "  - #{index['sql']}"
      end
    end
  end
end
```

### 2. Performance Monitoring Dashboard

```ruby
# app/models/query_optimization_result.rb
class QueryOptimizationResult < ApplicationRecord
  validates :optimization_score, presence: true, inclusion: { in: 0..100 }
  validates :issues_found, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_queries, presence: true, numericality: { greater_than: 0 }
  
  scope :recent, -> { where('analyzed_at > ?', 1.week.ago) }
  scope :by_score, ->(min_score) { where('optimization_score >= ?', min_score) }
  
  def self.average_score
    average(:optimization_score)
  end
  
  def self.trend_data
    recent.group_by_day(:analyzed_at).average(:optimization_score)
  end
end

# Migration
class CreateQueryOptimizationResults < ActiveRecord::Migration[7.1]
  def change
    create_table :query_optimization_results do |t|
      t.integer :optimization_score, null: false
      t.integer :issues_found, null: false
      t.integer :total_queries, null: false
      t.json :analysis_data
      t.datetime :analyzed_at, null: false
      
      t.timestamps
    end
    
    add_index :query_optimization_results, :analyzed_at
    add_index :query_optimization_results, :optimization_score
  end
end
```

### 3. Rake Tasks for Analysis

```ruby
# lib/tasks/query_optimizer.rake
namespace :query_optimizer do
  desc "Analyze all models for query optimization opportunities"
  task analyze_models: :environment do
    analyzer = CustomQueryAnalyzer.new
    
    ApplicationRecord.descendants.each do |model|
      next if model.abstract_class?
      
      puts "Analyzing #{model.name}..."
      analyzer.analyze_model_queries(model)
    end
  end
  
  desc "Run CI quality check"
  task :ci_check, [:threshold] => :environment do |t, args|
    threshold = args[:threshold]&.to_i || 80
    
    # Collect sample queries from your application
    queries = [
      { sql: User.where(active: true).to_sql, duration_ms: 50 },
      { sql: Post.includes(:user).to_sql, duration_ms: 120 }
    ]
    
    optimizer = QueryOptimizerService.new
    passed = optimizer.check_ci_quality(queries, threshold)
    
    if passed
      puts "✅ Query optimization check passed"
      exit 0
    else
      puts "❌ Query optimization check failed"
      exit 1
    end
  end
  
  desc "Generate optimization report"
  task report: :environment do
    results = QueryOptimizationResult.recent.order(:analyzed_at)
    
    puts "=== Query Optimization Report ==="
    puts "Average Score (Last 7 days): #{results.average(:optimization_score).round(1)}"
    puts "Total Analyses: #{results.count}"
    puts "Issues Found: #{results.sum(:issues_found)}"
    
    puts "\nTrend Data:"
    QueryOptimizationResult.trend_data.each do |date, score|
      puts "  #{date}: #{score.round(1)}"
    end
  end
end
```

## CI/CD Integration

### 1. GitHub Actions

```yaml
# .github/workflows/query_optimization.yml
name: Query Optimization Check

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  query-optimization:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:13
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: 3.2
        bundler-cache: true
    
    - name: Setup Database
      run: |
        bundle exec rails db:create
        bundle exec rails db:migrate
      env:
        DATABASE_URL: postgres://postgres:postgres@localhost:5432/test
    
    - name: Run Query Optimization Check
      run: bundle exec rake query_optimizer:ci_check[85]
      env:
        QUERY_OPTIMIZER_API_KEY: ${{ secrets.QUERY_OPTIMIZER_API_KEY }}
        QUERY_OPTIMIZER_API_URL: ${{ secrets.QUERY_OPTIMIZER_API_URL }}
        QUERY_OPTIMIZER_ENABLED: true
```

### 2. Custom CI Script

```ruby
# scripts/ci_query_check.rb
#!/usr/bin/env ruby

require_relative '../config/environment'

class CIQueryCheck
  def initialize(threshold = 80)
    @threshold = threshold
    @optimizer = QueryOptimizerService.new
  end
  
  def run
    queries = collect_representative_queries
    
    puts "Analyzing #{queries.length} representative queries..."
    
    result = @optimizer.analyze_queries(queries)
    
    unless result&.dig('success')
      puts "❌ Failed to analyze queries"
      exit 1
    end
    
    data = result['data']
    score = data['summary']['optimization_score']
    
    puts "\n=== Query Optimization Results ==="
    puts "Score: #{score}/100 (Threshold: #{@threshold})"
    puts "Issues Found: #{data['summary']['issues_found']}"
    
    if data['n_plus_one']['detected']
      puts "\n⚠️  N+1 Query Issues:"
      data['n_plus_one']['patterns'].each do |pattern|
        puts "  - #{pattern['table']}.#{pattern['column']}: #{pattern['suggestion']}"
      end
    end
    
    unless data['slow_queries'].empty?
      puts "\n🐌 Slow Query Issues:"
      data['slow_queries'].each do |query|
        puts "  - #{query['duration_ms']}ms: #{query['sql'][0..100]}..."
      end
    end
    
    unless data['missing_indexes'].empty?
      puts "\n📊 Missing Index Suggestions:"
      data['missing_indexes'].each do |index|
        puts "  - #{index['sql']}"
      end
    end
    
    if score >= @threshold
      puts "\n✅ Query optimization check passed!"
      exit 0
    else
      puts "\n❌ Query optimization check failed!"
      puts "Score #{score} is below threshold #{@threshold}"
      exit 1
    end
  end
  
  private
  
  def collect_representative_queries
    [
      # User queries
      { sql: User.where(active: true).to_sql, duration_ms: 45 },
      { sql: User.joins(:posts).to_sql, duration_ms: 120 },
      
      # Post queries  
      { sql: Post.includes(:user, :comments).to_sql, duration_ms: 200 },
      { sql: Post.where('created_at > ?', 1.week.ago).to_sql, duration_ms: 80 },
      
      # Search queries
      { sql: "SELECT * FROM posts WHERE title ILIKE '%search%'", duration_ms: 300 }
    ]
  end
end

# Run the check
threshold = ARGV[0]&.to_i || 80
CIQueryCheck.new(threshold).run
```

## Best Practices

### 1. Query Collection Strategy

```ruby
# Only collect queries in specific environments
def should_collect_queries?
  QueryOptimizerConfig.enabled? && 
  !Rails.env.test? && 
  !request.path.start_with?('/assets')
end

# Sample queries to avoid overwhelming the API
def should_sample_query?(query_count)
  return true if query_count <= 10
  return query_count % 10 == 0 if query_count <= 100
  query_count % 100 == 0
end
```

### 2. Error Handling

```ruby
def analyze_with_fallback(queries)
  optimizer = QueryOptimizerService.new
  result = optimizer.analyze_queries(queries)
  
  return result if result&.dig('success')
  
  # Fallback to local analysis
  Rails.logger.warn "Query Optimizer API unavailable, using local analysis"
  perform_local_analysis(queries)
rescue => e
  Rails.logger.error "Query analysis failed: #{e.message}"
  nil
end
```

### 3. Performance Considerations

```ruby
# Batch queries efficiently
def batch_analyze_queries(all_queries, batch_size = 50)
  all_queries.each_slice(batch_size) do |batch|
    QueryAnalysisJob.perform_later(batch)
  end
end

# Cache results to avoid repeated API calls
def cached_analysis(queries)
  cache_key = Digest::MD5.hexdigest(queries.to_json)
  
  Rails.cache.fetch("query_analysis:#{cache_key}", expires_in: 1.hour) do
    QueryOptimizerService.new.analyze_queries(queries)
  end
end
```

### 4. Monitoring and Alerting

```ruby
# app/services/query_alert_service.rb
class QueryAlertService
  def self.check_and_alert(analysis_result)
    return unless analysis_result&.dig('success')
    
    data = analysis_result['data']
    score = data['summary']['optimization_score']
    
    if score < 50
      send_critical_alert(data)
    elsif score < 70
      send_warning_alert(data)
    end
  end
  
  private
  
  def self.send_critical_alert(data)
    # Send to Slack, email, etc.
    Rails.logger.error "CRITICAL: Query optimization score below 50%"
  end
  
  def self.send_warning_alert(data)
    Rails.logger.warn "WARNING: Query optimization score below 70%"
  end
end
```
