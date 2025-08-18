# Rails Database Query Optimizer API

A powerful Rails API for analyzing and optimizing database queries in real-time. Detect N+1 queries, identify slow queries, suggest missing indexes, and get actionable optimization recommendations.

## Features

- 🔍 **N+1 Query Detection**: Automatically detect N+1 query patterns and suggest eager loading solutions
- 🐌 **Slow Query Analysis**: Identify slow queries with severity levels and optimization suggestions
- 📊 **Missing Index Detection**: Analyze WHERE clauses and suggest database indexes
- 🔐 **API Authentication**: Secure API key-based authentication with rate limiting
- 📈 **CI/CD Integration**: Built-in scoring system for continuous integration
- 🧪 **Comprehensive Testing**: 200+ test examples with full coverage

## Quick Start

### 1. Requirements

- **Ruby**: 3.2.0 or higher
- **Rails**: 8.0.0 or higher
- **PostgreSQL**: 13+ (required for JSON support)

### 2. Installation

Add to your Gemfile:

```ruby
gem 'rails', '~> 8.0.0'
gem 'pg', '~> 1.1'
gem 'pg_query', '~> 4.2'
gem 'bcrypt', '~> 3.1.7'
gem 'rack-cors'
```

### 3. Database Setup

```bash
rails db:create
rails db:migrate
```

### 4. Generate API Key

```bash
rails console
```

```ruby
# Create an app profile and generate API key
app_profile = AppProfile.create!(name: 'My Rails App')
api_key = app_profile.generate_api_key!
puts "Your API Key: #{api_key}"
```

### 5. Basic Usage

```ruby
require 'net/http'
require 'json'

# Analyze queries
uri = URI('http://localhost:3000/api/v1/analyze')
http = Net::HTTP.new(uri.host, uri.port)

request = Net::HTTP::Post.new(uri)
request['Content-Type'] = 'application/json'
request['X-API-Key'] = 'your_api_key_here'

request.body = {
  queries: [
    {
      sql: "SELECT * FROM users WHERE id = 1",
      duration_ms: 50
    },
    {
      sql: "SELECT * FROM posts WHERE user_id = 1",
      duration_ms: 200
    }
  ]
}.to_json

response = http.request(request)
result = JSON.parse(response.body)

puts result['data']['n_plus_one']
puts result['data']['slow_queries']
puts result['data']['missing_indexes']
```

## API Endpoints

### Authentication

All endpoints (except API key creation) require authentication via the `X-API-Key` header.

### POST /api/v1/api_keys

Create a new API key.

**Request:**
```json
{
  "app_name": "My Rails Application"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "app_name": "My Rails Application",
    "api_key": "abc123...",
    "created_at": "2024-01-15T10:30:00Z"
  }
}
```

### POST /api/v1/analyze

Analyze queries for optimization opportunities.

**Headers:**
- `X-API-Key`: Your API key
- `Content-Type`: application/json

**Request:**
```json
{
  "queries": [
    {
      "sql": "SELECT * FROM users WHERE id = ?",
      "duration_ms": 150
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "n_plus_one": {
      "detected": true,
      "patterns": [
        {
          "table": "posts",
          "column": "user_id",
          "query_count": 5,
          "suggestion": "Use includes(:posts) to preload associations"
        }
      ]
    },
    "slow_queries": [
      {
        "sql": "SELECT * FROM users WHERE email LIKE '%@gmail.com'",
        "duration_ms": 2000,
        "severity": "very_slow",
        "suggestions": ["Add index on email column", "Avoid leading wildcards"]
      }
    ],
    "missing_indexes": [
      {
        "table": "users",
        "columns": ["email"],
        "sql": "CREATE INDEX idx_users_email ON users (email);",
        "priority": "high"
      }
    ],
    "summary": {
      "total_queries": 10,
      "issues_found": 3,
      "optimization_score": 75
    }
  }
}
```

### POST /api/v1/analyze_ci

Analyze queries for CI/CD integration with pass/fail scoring.

**Request:**
```json
{
  "queries": [...],
  "threshold_score": 80
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "score": 85,
    "passed": true,
    "threshold": 80,
    "issues": {
      "n_plus_one": 1,
      "slow_queries": 2,
      "missing_indexes": 1,
      "total": 4
    },
    "recommendations": [
      "Add eager loading for user associations",
      "Create index on posts.user_id"
    ]
  }
}
```

### GET /api/v1/health

Check API health status.

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0.0",
  "services": {
    "database": "ok",
    "sql_parser": "ok",
    "analysis_services": "ok"
  }
}
```

## Integration Examples

### Rails Application Integration

```ruby
# app/services/query_optimizer_service.rb
class QueryOptimizerService
  API_BASE_URL = 'http://localhost:3000/api/v1'

  def initialize(api_key)
    @api_key = api_key
  end

  def analyze_queries(queries)
    uri = URI("#{API_BASE_URL}/analyze")
    http = Net::HTTP.new(uri.host, uri.port)

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['X-API-Key'] = @api_key

    request.body = { queries: queries }.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end

  def check_ci_quality(queries, threshold = 80)
    uri = URI("#{API_BASE_URL}/analyze_ci")
    http = Net::HTTP.new(uri.host, uri.port)

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['X-API-Key'] = @api_key

    request.body = {
      queries: queries,
      threshold_score: threshold
    }.to_json

    response = http.request(request)
    result = JSON.parse(response.body)

    result.dig('data', 'passed')
  end
end

# Usage in your Rails app
optimizer = QueryOptimizerService.new(ENV['QUERY_OPTIMIZER_API_KEY'])

# Collect queries from your application
queries = [
  {
    sql: User.where(active: true).to_sql,
    duration_ms: 45
  }
]

# Analyze for optimization opportunities
result = optimizer.analyze_queries(queries)

if result['data']['n_plus_one']['detected']
  Rails.logger.warn "N+1 queries detected: #{result['data']['n_plus_one']['patterns']}"
end
```

### CI/CD Integration

```yaml
# .github/workflows/query_optimization.yml
name: Query Optimization Check

on: [push, pull_request]

jobs:
  query-optimization:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2

    - name: Setup Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: 3.2

    - name: Install dependencies
      run: bundle install

    - name: Run query optimization check
      run: |
        ruby scripts/check_query_optimization.rb
      env:
        QUERY_OPTIMIZER_API_KEY: ${{ secrets.QUERY_OPTIMIZER_API_KEY }}
        OPTIMIZATION_THRESHOLD: 85
```

```ruby
# scripts/check_query_optimization.rb
require 'net/http'
require 'json'

# Collect sample queries from your test suite
queries = [
  { sql: "SELECT * FROM users WHERE active = true", duration_ms: 50 },
  { sql: "SELECT * FROM posts WHERE user_id = 1", duration_ms: 120 }
]

uri = URI('http://your-optimizer-api.com/api/v1/analyze_ci')
http = Net::HTTP.new(uri.host, uri.port)

request = Net::HTTP::Post.new(uri)
request['Content-Type'] = 'application/json'
request['X-API-Key'] = ENV['QUERY_OPTIMIZER_API_KEY']

request.body = {
  queries: queries,
  threshold_score: ENV['OPTIMIZATION_THRESHOLD'].to_i
}.to_json

response = http.request(request)
result = JSON.parse(response.body)

if result['data']['passed']
  puts "✅ Query optimization check passed (Score: #{result['data']['score']})"
  exit 0
else
  puts "❌ Query optimization check failed (Score: #{result['data']['score']})"
  puts "Issues found:"
  result['data']['recommendations'].each { |rec| puts "  - #{rec}" }
  exit 1
end
```

## Rate Limits

- **1000 requests per hour** per API key
- Rate limit headers included in responses
- Contact support for higher limits

## Error Handling

All endpoints return consistent error responses:

```json
{
  "success": false,
  "error": "Error message",
  "errors": ["Detailed error 1", "Detailed error 2"]
}
```

Common HTTP status codes:
- `400` - Bad Request (validation errors)
- `401` - Unauthorized (invalid/missing API key)
- `429` - Too Many Requests (rate limit exceeded)
- `500` - Internal Server Error

## Development

### Running Tests

```bash
bundle exec rspec
```

### Starting the Server

```bash
rails server
```

### Environment Variables

```bash
# .env
DATABASE_URL=postgresql://user:password@localhost/query_optimizer_development
RAILS_ENV=development
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
