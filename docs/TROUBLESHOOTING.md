# Troubleshooting Guide

Common issues and solutions for the Rails Database Query Optimizer API.

## Table of Contents

1. [API Connection Issues](#api-connection-issues)
2. [Authentication Problems](#authentication-problems)
3. [Query Analysis Issues](#query-analysis-issues)
4. [Performance Problems](#performance-problems)
5. [Database Issues](#database-issues)
6. [Deployment Issues](#deployment-issues)
7. [Monitoring and Debugging](#monitoring-and-debugging)

## API Connection Issues

### Issue: Connection Refused

**Symptoms:**
```
Errno::ECONNREFUSED: Connection refused - connect(2) for "localhost" port 3000
```

**Solutions:**

1. **Check if the API server is running:**
```bash
# Check if process is running
ps aux | grep puma

# Check if port is open
lsof -i :3000

# Start the server if not running
bundle exec rails server
```

2. **Verify the API URL:**
```ruby
# Check your configuration
puts QueryOptimizerConfig.api_url
# Should output: http://localhost:3000/api/v1
```

3. **Check firewall settings:**
```bash
# On macOS
sudo pfctl -sr | grep 3000

# On Linux
sudo iptables -L | grep 3000
```

### Issue: Timeout Errors

**Symptoms:**
```
Net::ReadTimeout: Net::ReadTimeout with #<TCPSocket:(closed)>
```

**Solutions:**

1. **Increase timeout values:**
```ruby
# In your service class
class QueryOptimizerService
  include HTTParty
  
  default_timeout 60  # Increase from default 30 seconds
end
```

2. **Check server load:**
```bash
# Monitor server resources
top
htop
iostat 1
```

3. **Optimize query batch size:**
```ruby
# Reduce batch size for large query sets
def analyze_queries_in_batches(queries, batch_size = 25)
  queries.each_slice(batch_size) do |batch|
    analyze_queries(batch)
  end
end
```

## Authentication Problems

### Issue: Invalid API Key

**Symptoms:**
```json
{
  "success": false,
  "error": "Invalid API key"
}
```

**Solutions:**

1. **Verify API key format:**
```ruby
# API keys should be 64 characters long
api_key = ENV['QUERY_OPTIMIZER_API_KEY']
puts "API Key length: #{api_key.length}"  # Should be 64
puts "API Key format: #{api_key.match?(/\A[a-f0-9]{64}\z/)}"  # Should be true
```

2. **Check API key in database:**
```ruby
# In Rails console
api_key = 'your_api_key_here'
digest = BCrypt::Password.create(api_key)
app_profile = AppProfile.find_by(api_key_digest: digest)
puts app_profile ? "Found: #{app_profile.name}" : "Not found"
```

3. **Regenerate API key:**
```ruby
# In Rails console
app_profile = AppProfile.find_by(name: 'Your App Name')
new_api_key = app_profile.generate_api_key!
puts "New API Key: #{new_api_key}"
```

### Issue: Rate Limit Exceeded

**Symptoms:**
```json
{
  "success": false,
  "error": "Rate limit exceeded. Maximum 1000 requests per hour."
}
```

**Solutions:**

1. **Check current rate limit status:**
```ruby
# Check Redis cache for rate limit
cache_key = "rate_limit:#{app_profile.id}"
current_count = Rails.cache.read(cache_key)
puts "Current requests: #{current_count}/1000"
```

2. **Implement exponential backoff:**
```ruby
def analyze_with_retry(queries, max_retries = 3)
  retries = 0
  
  begin
    analyze_queries(queries)
  rescue => e
    if e.message.include?('Rate limit') && retries < max_retries
      wait_time = 2 ** retries
      Rails.logger.warn "Rate limited, waiting #{wait_time} seconds..."
      sleep(wait_time)
      retries += 1
      retry
    else
      raise e
    end
  end
end
```

3. **Optimize request frequency:**
```ruby
# Batch queries and reduce frequency
def collect_and_analyze_periodically
  @query_buffer ||= []
  @query_buffer.concat(new_queries)
  
  # Analyze every 100 queries or every 5 minutes
  if @query_buffer.length >= 100 || last_analysis_time < 5.minutes.ago
    analyze_queries(@query_buffer)
    @query_buffer.clear
    @last_analysis_time = Time.current
  end
end
```

## Query Analysis Issues

### Issue: SQL Parsing Errors

**Symptoms:**
```json
{
  "success": false,
  "errors": ["Query 1: Must be a valid SQL statement"]
}
```

**Solutions:**

1. **Validate SQL before sending:**
```ruby
def validate_sql(sql)
  # Basic validation
  return false if sql.blank?
  return false unless sql.match?(/\b(SELECT|INSERT|UPDATE|DELETE)\b/i)
  
  # Check for dangerous patterns
  dangerous_patterns = [/\bDROP\b/i, /\bTRUNCATE\b/i, /\bALTER\b/i]
  return false if dangerous_patterns.any? { |pattern| sql.match?(pattern) }
  
  true
end

queries = queries.select { |q| validate_sql(q[:sql]) }
```

2. **Clean up SQL queries:**
```ruby
def clean_sql(sql)
  # Remove comments
  sql = sql.gsub(/--.*$/, '').gsub(/\/\*.*?\*\//m, '')
  
  # Normalize whitespace
  sql = sql.gsub(/\s+/, ' ').strip
  
  # Remove trailing semicolon
  sql = sql.chomp(';')
  
  sql
end
```

3. **Handle ActiveRecord generated SQL:**
```ruby
def extract_sql_from_activerecord(relation)
  {
    sql: relation.to_sql,
    duration_ms: measure_query_time { relation.load }
  }
end

def measure_query_time
  start_time = Time.current
  yield
  ((Time.current - start_time) * 1000).round(2)
end
```

### Issue: No Optimization Suggestions

**Symptoms:**
- API returns success but no suggestions
- Empty arrays for n_plus_one, slow_queries, missing_indexes

**Solutions:**

1. **Check query thresholds:**
```ruby
# Queries might be too fast to trigger analysis
queries_with_artificial_duration = queries.map do |q|
  {
    sql: q[:sql],
    duration_ms: q[:duration_ms] || 100  # Add minimum duration
  }
end
```

2. **Verify query patterns:**
```ruby
# For N+1 detection, you need multiple similar queries
n_plus_one_queries = [
  { sql: "SELECT * FROM posts WHERE user_id = 1", duration_ms: 50 },
  { sql: "SELECT * FROM posts WHERE user_id = 2", duration_ms: 50 },
  { sql: "SELECT * FROM posts WHERE user_id = 3", duration_ms: 50 },
  { sql: "SELECT * FROM posts WHERE user_id = 4", duration_ms: 50 }
]
```

3. **Include WHERE clauses for index suggestions:**
```ruby
# Queries need WHERE clauses to suggest indexes
queries_with_conditions = [
  { sql: "SELECT * FROM users WHERE email = 'test@example.com'", duration_ms: 100 },
  { sql: "SELECT * FROM posts WHERE created_at > '2024-01-01'", duration_ms: 200 }
]
```

## Performance Problems

### Issue: Slow API Response Times

**Symptoms:**
- API requests taking > 5 seconds
- Timeout errors

**Solutions:**

1. **Monitor API performance:**
```ruby
# Add timing to your service
class QueryOptimizerService
  def analyze_queries(queries)
    start_time = Time.current
    
    result = make_api_request(queries)
    
    duration = Time.current - start_time
    Rails.logger.info "Query analysis took #{duration.round(2)}s for #{queries.length} queries"
    
    result
  end
end
```

2. **Optimize query batch sizes:**
```ruby
# Test different batch sizes
[10, 25, 50, 100].each do |batch_size|
  start_time = Time.current
  
  large_query_set.each_slice(batch_size) do |batch|
    analyze_queries(batch)
  end
  
  total_time = Time.current - start_time
  puts "Batch size #{batch_size}: #{total_time.round(2)}s total"
end
```

3. **Use background processing:**
```ruby
# Process analysis asynchronously
class QueryAnalysisJob < ApplicationJob
  def perform(queries)
    optimizer = QueryOptimizerService.new
    result = optimizer.analyze_queries(queries)
    
    # Store or process results
    handle_analysis_result(result)
  end
end

# Usage
QueryAnalysisJob.perform_later(queries)
```

### Issue: High Memory Usage

**Symptoms:**
- Server running out of memory
- Slow garbage collection

**Solutions:**

1. **Monitor memory usage:**
```ruby
# Add memory monitoring
def analyze_with_memory_monitoring(queries)
  before_memory = `ps -o rss= -p #{Process.pid}`.to_i
  
  result = analyze_queries(queries)
  
  after_memory = `ps -o rss= -p #{Process.pid}`.to_i
  memory_diff = after_memory - before_memory
  
  Rails.logger.info "Memory usage increased by #{memory_diff}KB"
  
  result
end
```

2. **Implement query streaming:**
```ruby
# Process queries in smaller chunks
def stream_query_analysis(queries)
  queries.each_slice(10) do |batch|
    analyze_queries(batch)
    
    # Force garbage collection periodically
    GC.start if rand(10) == 0
  end
end
```

## Database Issues

### Issue: PostgreSQL Connection Errors

**Symptoms:**
```
PG::ConnectionBad: could not connect to server
```

**Solutions:**

1. **Check database configuration:**
```ruby
# In Rails console
puts ActiveRecord::Base.connection_config
puts ActiveRecord::Base.connection.execute("SELECT version()").first
```

2. **Verify database permissions:**
```sql
-- Check user permissions
SELECT * FROM pg_user WHERE usename = 'your_username';

-- Check database access
SELECT datname FROM pg_database WHERE datname = 'your_database';
```

3. **Test connection manually:**
```bash
# Test PostgreSQL connection
psql -h localhost -U username -d database_name -c "SELECT 1;"
```

### Issue: Migration Failures

**Symptoms:**
```
ActiveRecord::StatementInvalid: PG::UndefinedTable
```

**Solutions:**

1. **Check migration status:**
```bash
bundle exec rails db:migrate:status
```

2. **Run migrations step by step:**
```bash
# Run one migration at a time
bundle exec rails db:migrate:up VERSION=20240101000001
```

3. **Reset database if needed:**
```bash
# CAUTION: This will destroy all data
bundle exec rails db:drop db:create db:migrate
```

## Deployment Issues

### Issue: Docker Build Failures

**Symptoms:**
```
ERROR: failed to solve: process "/bin/sh -c bundle install" did not complete successfully
```

**Solutions:**

1. **Check Dockerfile dependencies:**
```dockerfile
# Ensure all required packages are installed
RUN apk add --no-cache \
  build-base \
  postgresql-dev \
  git \
  curl
```

2. **Clear Docker cache:**
```bash
docker system prune -a
docker build --no-cache .
```

3. **Check gem compatibility:**
```ruby
# In Gemfile, specify platform
gem 'pg', '~> 1.1', platforms: [:ruby]
```

### Issue: Environment Variable Problems

**Symptoms:**
- Configuration not loading
- Default values being used

**Solutions:**

1. **Verify environment variables:**
```bash
# Check if variables are set
env | grep QUERY_OPTIMIZER
echo $QUERY_OPTIMIZER_API_KEY
```

2. **Debug configuration loading:**
```ruby
# In Rails console
puts "API URL: #{ENV['QUERY_OPTIMIZER_API_URL']}"
puts "API Key present: #{ENV['QUERY_OPTIMIZER_API_KEY'].present?}"
puts "Enabled: #{ENV['QUERY_OPTIMIZER_ENABLED']}"
```

3. **Check .env file loading:**
```ruby
# In config/application.rb
if Rails.env.development?
  require 'dotenv/rails-now'
  puts "Loaded .env file: #{File.exist?('.env')}"
end
```

## Monitoring and Debugging

### Enable Debug Logging

```ruby
# config/environments/development.rb
config.log_level = :debug

# In your service class
class QueryOptimizerService
  def analyze_queries(queries)
    Rails.logger.debug "Analyzing #{queries.length} queries"
    Rails.logger.debug "API URL: #{self.class.base_uri}"
    Rails.logger.debug "Request body: #{queries.to_json}"
    
    response = make_request(queries)
    
    Rails.logger.debug "Response status: #{response.code}"
    Rails.logger.debug "Response body: #{response.body}"
    
    response
  end
end
```

### Health Check Debugging

```ruby
# Test individual health check components
def debug_health_checks
  puts "Database: #{check_database}"
  puts "Redis: #{check_redis}"
  puts "SQL Parser: #{check_sql_parser}"
  puts "Analysis Services: #{check_analysis_services}"
end

def check_sql_parser
  parser = SqlParserService.new("SELECT 1")
  parser.valid? ? 'ok' : 'error'
rescue => e
  Rails.logger.error "SQL Parser error: #{e.message}"
  'error'
end
```

### Performance Profiling

```ruby
# Add profiling to identify bottlenecks
require 'benchmark'

def profile_analysis(queries)
  result = nil
  
  time = Benchmark.measure do
    result = analyze_queries(queries)
  end
  
  Rails.logger.info "Query analysis profile:"
  Rails.logger.info "  User CPU time: #{time.utime}s"
  Rails.logger.info "  System CPU time: #{time.stime}s"
  Rails.logger.info "  Total time: #{time.real}s"
  
  result
end
```

### Common Log Patterns

```bash
# Search for common issues in logs
grep "Rate limit exceeded" log/production.log
grep "Invalid API key" log/production.log
grep "Connection refused" log/production.log
grep "Timeout" log/production.log

# Monitor API response times
grep "Query analysis took" log/production.log | tail -20

# Check error patterns
grep "ERROR" log/production.log | tail -10
```

### Testing API Connectivity

```bash
# Test API endpoints manually
curl -X POST http://localhost:3000/api/v1/analyze \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your_api_key" \
  -d '{"queries":[{"sql":"SELECT 1","duration_ms":10}]}'

# Test health endpoint
curl http://localhost:3000/api/v1/health

# Test with verbose output
curl -v -X POST http://localhost:3000/api/v1/analyze \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your_api_key" \
  -d '{"queries":[]}'
```

This troubleshooting guide covers the most common issues you might encounter when using the Query Optimizer API. For issues not covered here, check the application logs and consider enabling debug logging for more detailed information.
