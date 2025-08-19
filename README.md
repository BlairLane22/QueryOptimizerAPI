# QueryWise

A Ruby gem for integrating with the Rails Database Query Optimizer API to detect N+1 queries, slow queries, and missing indexes in your Rails applications.

[![Gem Version](https://badge.fury.io/rb/QueryWise.svg)](https://badge.fury.io/rb/QueryWise)
[![Build Status](https://github.com/BlairLane22/QueryWise/workflows/CI/badge.svg)](https://github.com/BlairLane22/QueryWise/actions)

## Features

- 🔍 **N+1 Query Detection** - Automatically detect N+1 query patterns
- 🐌 **Slow Query Analysis** - Identify slow queries with optimization suggestions
- 📊 **Missing Index Detection** - Get recommendations for database indexes
- 🚀 **Rails Integration** - Seamless integration with Rails applications
- 📈 **CI/CD Support** - Built-in support for continuous integration
- 🔧 **Configurable** - Flexible configuration options
- 📝 **Comprehensive Logging** - Detailed logging and error handling

## Step-by-Step Implementation Guide

Follow this guide to implement Query Optimizer Client in your Rails project in under an hour:

### Step 1: Install the Gem (2 minutes)

Add to your `Gemfile`:

```ruby
gem 'QueryWise'
```

Run bundle install:

```bash
bundle install
```

### Step 2: Generate Configuration Files (1 minute)

Run the installation generator:

```bash
rails generate QueryWise:install
```

This creates:
- `config/initializers/query_optimizer_client.rb` - Configuration file
- `app/jobs/query_optimizer_client/analysis_job.rb` - Background job
- `.env` file with configuration template

### Step 3: Set Up API Connection (5 minutes)

#### Option A: Use Hosted API (Recommended)
```bash
# Add to your .env file
QUERY_OPTIMIZER_API_URL=https://your-hosted-api.com/api/v1
QUERY_OPTIMIZER_API_KEY=your_api_key_here
QUERY_OPTIMIZER_ENABLED=true
```

#### Option B: Run API Locally
```bash
# Clone and start the API server
git clone https://github.com/yourusername/query-optimizer-api
cd query-optimizer-api
bundle install
rails db:create db:migrate
rails server

# In your app's .env file
QUERY_OPTIMIZER_API_URL=http://localhost:3000/api/v1
QUERY_OPTIMIZER_ENABLED=true
```

### Step 4: Generate API Key (2 minutes)

```bash
# Generate an API key for your application
rails query_optimizer:generate_key["My Rails App"]

# Copy the generated key to your .env file
QUERY_OPTIMIZER_API_KEY=abc123def456...
```

### Step 5: Test Your Setup (2 minutes)

```bash
# Verify configuration and connectivity
rails query_optimizer:check

# Should output:
# ✅ API connection successful
# Version: 1.0.0
# Services: {"database":"ok","sql_parser":"ok"}
```

### Step 6: Run Your First Analysis (5 minutes)

```bash
# Analyze sample queries from your application
rails query_optimizer:analyze

# Example output:
# 📊 Analysis Results
# Overall Score: 75/100
# Issues Found: 2
# 🔍 N+1 Query Issues:
#   ⚠️  posts.user_id
#      💡 Use includes(:user) to preload associations
```

### Step 7: Set Up Automatic Monitoring (10 minutes)

The middleware is automatically enabled. Test it by:

1. **Start your Rails server:**
```bash
rails server
```

2. **Visit a page with database queries:**
```bash
# Navigate to a page like /users or /posts
curl http://localhost:3000/users
```

3. **Check your logs for analysis results:**
```bash
tail -f log/development.log | grep "Query analysis"
```

You should see logs like:
```
Query analysis completed on GET /users: Score 85%, 1 issues found
N+1 queries detected on GET /users:
  - posts.user_id: Use includes(:posts) to preload associations
```

### Step 8: Configure for Your Needs (15 minutes)

Edit `config/initializers/query_optimizer_client.rb`:

```ruby
QueryOptimizerClient.configure do |config|
  # Basic settings
  config.enabled = Rails.env.production? || Rails.env.development?
  config.default_threshold = 80  # Minimum acceptable score

  # Performance settings
  config.timeout = 30           # API request timeout
  config.batch_size = 50        # Max queries per request
  config.retries = 3            # Retry failed requests

  # Monitoring settings - customize what gets analyzed
  Rails.application.config.query_optimizer_client.min_queries = 5    # Only analyze requests with 5+ queries
  Rails.application.config.query_optimizer_client.skip_paths = [
    '/assets', '/health', '/admin'  # Skip these paths
  ]
end
```

### Step 9: Set Up CI/CD Integration (10 minutes)

Add to your CI pipeline (e.g., `.github/workflows/ci.yml`):

```yaml
- name: Database Performance Check
  run: bundle exec rails query_optimizer:ci[85]
  env:
    QUERY_OPTIMIZER_API_KEY: ${{ secrets.QUERY_OPTIMIZER_API_KEY }}
    QUERY_OPTIMIZER_ENABLED: true
```

Or add to your test suite:

```ruby
# spec/performance/query_performance_spec.rb
RSpec.describe "Query Performance" do
  it "maintains good performance" do
    # Your test queries here
    queries = [
      { sql: User.where(active: true).to_sql, duration_ms: 45 }
    ]

    result = QueryOptimizerClient.analyze_for_ci(queries, threshold: 85)
    expect(result['data']['passed']).to be true
  end
end
```

### Step 10: Customize Alerts and Actions (10 minutes)

Edit `app/jobs/query_optimizer_client/analysis_job.rb` to add custom behavior:

```ruby
def send_alerts(data, endpoint, score)
  if score < 50
    # Send to Slack
    SlackNotifier.ping("🚨 Critical performance issue on #{endpoint}: #{score}%")

    # Send email alert
    PerformanceMailer.critical_alert(endpoint, data).deliver_now

    # Create GitHub issue
    create_github_issue(endpoint, data) if Rails.env.production?
  end
end

def store_analysis_results(data, endpoint)
  # Store in your database for trending
  PerformanceMetric.create!(
    endpoint: endpoint,
    score: data['summary']['optimization_score'],
    issues: data['summary']['issues_found'],
    analysis_data: data,
    measured_at: Time.current
  )
end
```

### 🎉 You're Done! (Total time: ~45 minutes)

Your Rails application now has:

✅ **Automatic N+1 query detection**
✅ **Slow query identification**
✅ **Missing index recommendations**
✅ **Real-time performance monitoring**
✅ **CI/CD integration**
✅ **Custom alerts and actions**

## Next Steps

- **Monitor your dashboard** for performance insights
- **Review the analysis results** and implement suggested optimizations
- **Set up alerts** for critical performance issues
- **Track performance trends** over time
- **Share results** with your team

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'query_optimizer_client'
```

And then execute:

```bash
bundle install
```

## Usage

### Basic Analysis

```ruby
# Analyze queries manually
queries = [
  {
    sql: "SELECT * FROM users WHERE id = 1",
    duration_ms: 50
  },
  {
    sql: "SELECT * FROM posts WHERE user_id = 1",
    duration_ms: 200
  }
]

result = QueryOptimizerClient.analyze_queries(queries)

if result['success']
  puts "Optimization Score: #{result['data']['summary']['optimization_score']}%"
  puts "Issues Found: #{result['data']['summary']['issues_found']}"
end
```

### Automatic Monitoring

The gem automatically monitors your Rails application when enabled:

```ruby
# config/initializers/query_optimizer_client.rb
QueryOptimizerClient.configure do |config|
  config.enabled = true
  config.api_key = ENV['QUERY_OPTIMIZER_API_KEY']
  # Middleware will automatically collect and analyze queries
end
```

### CI/CD Integration

Add to your CI pipeline:

```bash
# Check if your app meets the 85% performance threshold
rails query_optimizer:ci[85]
```

Or in your test suite:

```ruby
RSpec.describe "Performance" do
  it "maintains good query performance" do
    queries = collect_test_queries
    result = QueryOptimizerClient.analyze_for_ci(queries, threshold: 85)

    expect(result['data']['passed']).to be true
  end
end
```

### GitHub Actions Example

```yaml
name: Performance Check
on: [push, pull_request]

jobs:
  performance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - name: Setup Database
        run: |
          bundle exec rails db:create db:migrate
      - name: Run Performance Check
        run: bundle exec rails query_optimizer:ci[85]
        env:
          QUERY_OPTIMIZER_API_KEY: ${{ secrets.QUERY_OPTIMIZER_API_KEY }}
```

## Configuration

### Environment Variables

```bash
# Required
QUERY_OPTIMIZER_API_URL=http://localhost:3000/api/v1
QUERY_OPTIMIZER_API_KEY=your_64_character_api_key

# Optional
QUERY_OPTIMIZER_ENABLED=true
QUERY_OPTIMIZER_TIMEOUT=30
QUERY_OPTIMIZER_RETRIES=3
QUERY_OPTIMIZER_THRESHOLD=80
QUERY_OPTIMIZER_BATCH_SIZE=50
QUERY_OPTIMIZER_RATE_LIMIT_RETRY=true
```

### Initializer Configuration

```ruby
# config/initializers/query_optimizer_client.rb
QueryOptimizerClient.configure do |config|
  config.api_url = 'https://your-api-server.com/api/v1'
  config.api_key = ENV['QUERY_OPTIMIZER_API_KEY']
  config.enabled = Rails.env.production?
  config.timeout = 30
  config.retries = 3
  config.default_threshold = 80
  config.batch_size = 50
  config.rate_limit_retry = true
  config.logger = Rails.logger
end
```

## Rake Tasks

```bash
# Check configuration and connectivity
rails query_optimizer:check

# Analyze sample queries from your application
rails query_optimizer:analyze

# Run CI performance check with threshold
rails query_optimizer:ci[85]

# Generate a new API key
rails query_optimizer:generate_key["App Name"]
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yourusername/query_optimizer_client.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
