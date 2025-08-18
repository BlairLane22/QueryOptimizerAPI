# Practical Examples

Real-world examples of using the Rails Database Query Optimizer API.

## Table of Contents

1. [N+1 Query Detection](#n1-query-detection)
2. [Slow Query Optimization](#slow-query-optimization)
3. [Missing Index Detection](#missing-index-detection)
4. [CI/CD Integration](#cicd-integration)
5. [Performance Monitoring](#performance-monitoring)

## N+1 Query Detection

### Example 1: Blog Posts with Authors

**Problematic Code:**
```ruby
# app/controllers/posts_controller.rb
def index
  @posts = Post.limit(10)
end

# app/views/posts/index.html.erb
<% @posts.each do |post| %>
  <div class="post">
    <h3><%= post.title %></h3>
    <p>By: <%= post.user.name %></p> <!-- N+1 query here -->
  </div>
<% end %>
```

**Queries Generated:**
```sql
SELECT * FROM posts LIMIT 10;
SELECT * FROM users WHERE id = 1;
SELECT * FROM users WHERE id = 2;
SELECT * FROM users WHERE id = 3;
-- ... 10 total user queries
```

**API Analysis:**
```ruby
queries = [
  { sql: "SELECT * FROM posts LIMIT 10", duration_ms: 50 },
  { sql: "SELECT * FROM users WHERE id = 1", duration_ms: 25 },
  { sql: "SELECT * FROM users WHERE id = 2", duration_ms: 25 },
  { sql: "SELECT * FROM users WHERE id = 3", duration_ms: 25 }
  # ... more user queries
]

optimizer = QueryOptimizerService.new
result = optimizer.analyze_queries(queries)

# Result:
{
  "n_plus_one": {
    "detected": true,
    "patterns": [
      {
        "table": "users",
        "column": "id",
        "query_count": 10,
        "suggestion": "Use includes(:user) to preload associations",
        "example_sql": "Post.includes(:user).limit(10)",
        "severity": "high"
      }
    ]
  }
}
```

**Fixed Code:**
```ruby
# app/controllers/posts_controller.rb
def index
  @posts = Post.includes(:user).limit(10)
end
```

### Example 2: Nested Associations

**Problematic Code:**
```ruby
def show_user_posts_with_comments
  user = User.find(params[:id])
  user.posts.each do |post|
    puts "Post: #{post.title}"
    post.comments.each do |comment|  # N+1 for comments
      puts "  Comment by: #{comment.user.name}"  # N+1 for comment users
    end
  end
end
```

**API Analysis Result:**
```json
{
  "n_plus_one": {
    "detected": true,
    "patterns": [
      {
        "table": "comments",
        "column": "post_id",
        "query_count": 15,
        "suggestion": "Use includes(posts: :comments) to preload associations"
      },
      {
        "table": "users",
        "column": "id", 
        "query_count": 45,
        "suggestion": "Use includes(posts: { comments: :user }) for nested preloading"
      }
    ]
  }
}
```

**Fixed Code:**
```ruby
def show_user_posts_with_comments
  user = User.includes(posts: { comments: :user }).find(params[:id])
  user.posts.each do |post|
    puts "Post: #{post.title}"
    post.comments.each do |comment|
      puts "  Comment by: #{comment.user.name}"  # No additional queries
    end
  end
end
```

## Slow Query Optimization

### Example 1: Inefficient Search

**Problematic Query:**
```ruby
# Searching for users by email with leading wildcard
users = User.where("email LIKE ?", "%@gmail.com")
```

**API Analysis:**
```ruby
queries = [
  { 
    sql: "SELECT * FROM users WHERE email LIKE '%@gmail.com'", 
    duration_ms: 2500 
  }
]

result = optimizer.analyze_queries(queries)

# Result:
{
  "slow_queries": [
    {
      "sql": "SELECT * FROM users WHERE email LIKE '%@gmail.com'",
      "duration_ms": 2500,
      "severity": "very_slow",
      "suggestions": [
        "Avoid leading wildcards in LIKE queries",
        "Consider using full-text search",
        "Add functional index if leading wildcards are necessary"
      ],
      "estimated_improvement": "90% faster with proper indexing"
    }
  ],
  "missing_indexes": [
    {
      "table": "users",
      "columns": ["email"],
      "sql": "CREATE INDEX idx_users_email ON users (email);",
      "priority": "high"
    }
  ]
}
```

**Optimized Solutions:**

**Option 1: Reverse the search pattern**
```ruby
# Instead of leading wildcard, use trailing wildcard with domain extraction
domain = "@gmail.com"
users = User.where("email LIKE ?", "%#{domain}")
```

**Option 2: Full-text search**
```ruby
# Add full-text search capability
class User < ApplicationRecord
  include PgSearch::Model
  pg_search_scope :search_by_email, against: :email
end

users = User.search_by_email("gmail.com")
```

**Option 3: Functional index**
```sql
-- For cases where leading wildcards are necessary
CREATE INDEX idx_users_email_reverse ON users (reverse(email));
```

### Example 2: Complex JOIN Query

**Problematic Query:**
```ruby
# Finding active users with recent posts and comments
query = User.joins(:posts, :comments)
           .where(active: true)
           .where('posts.created_at > ?', 1.month.ago)
           .where('comments.created_at > ?', 1.week.ago)
           .distinct
```

**API Analysis Result:**
```json
{
  "slow_queries": [
    {
      "sql": "SELECT DISTINCT users.* FROM users INNER JOIN posts ON posts.user_id = users.id INNER JOIN comments ON comments.user_id = users.id WHERE users.active = true AND posts.created_at > '2024-01-01' AND comments.created_at > '2024-01-15'",
      "duration_ms": 3200,
      "severity": "very_slow",
      "suggestions": [
        "Add composite index on (user_id, created_at) for posts table",
        "Add composite index on (user_id, created_at) for comments table", 
        "Consider breaking into separate queries",
        "Add index on users.active column"
      ]
    }
  ],
  "missing_indexes": [
    {
      "table": "posts",
      "columns": ["user_id", "created_at"],
      "sql": "CREATE INDEX idx_posts_user_created ON posts (user_id, created_at);"
    },
    {
      "table": "comments", 
      "columns": ["user_id", "created_at"],
      "sql": "CREATE INDEX idx_comments_user_created ON comments (user_id, created_at);"
    }
  ]
}
```

**Optimized Solution:**
```ruby
# Break into separate queries for better performance
recent_post_user_ids = Post.where('created_at > ?', 1.month.ago).distinct.pluck(:user_id)
recent_comment_user_ids = Comment.where('created_at > ?', 1.week.ago).distinct.pluck(:user_id)
common_user_ids = recent_post_user_ids & recent_comment_user_ids

active_users = User.where(active: true, id: common_user_ids)
```

## Missing Index Detection

### Example 1: WHERE Clause Analysis

**Query:**
```ruby
orders = Order.where(status: 'pending', created_at: Date.current.beginning_of_day..Date.current.end_of_day)
```

**API Analysis:**
```json
{
  "missing_indexes": [
    {
      "table": "orders",
      "columns": ["status", "created_at"],
      "sql": "CREATE INDEX idx_orders_status_created ON orders (status, created_at);",
      "priority": "high",
      "estimated_impact": "Reduce query time from 800ms to 50ms",
      "usage_frequency": "high"
    }
  ]
}
```

**Implementation:**
```ruby
# db/migrate/add_orders_status_created_index.rb
class AddOrdersStatusCreatedIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :orders, [:status, :created_at], name: 'idx_orders_status_created'
  end
end
```

### Example 2: Foreign Key Optimization

**Query:**
```ruby
user_posts = Post.where(user_id: current_user.id).order(:created_at)
```

**API Analysis:**
```json
{
  "missing_indexes": [
    {
      "table": "posts",
      "columns": ["user_id", "created_at"],
      "sql": "CREATE INDEX idx_posts_user_created ON posts (user_id, created_at);",
      "priority": "medium",
      "estimated_impact": "Optimize ORDER BY with foreign key filtering"
    }
  ]
}
```

## CI/CD Integration

### Example 1: GitHub Actions Integration

```yaml
# .github/workflows/performance.yml
name: Performance Check

on:
  pull_request:
    branches: [ main ]

jobs:
  query-performance:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: 3.2
        bundler-cache: true
    
    - name: Setup Database
      run: |
        bundle exec rails db:create db:migrate
        bundle exec rails db:seed
    
    - name: Run Performance Tests
      run: |
        bundle exec rspec spec/performance/
        bundle exec ruby scripts/query_performance_check.rb
      env:
        QUERY_OPTIMIZER_API_KEY: ${{ secrets.QUERY_OPTIMIZER_API_KEY }}
        PERFORMANCE_THRESHOLD: 85
```

### Example 2: Performance Test Suite

```ruby
# spec/performance/query_performance_spec.rb
RSpec.describe "Query Performance", type: :request do
  let(:optimizer) { QueryOptimizerService.new }
  
  it "maintains good performance for user dashboard" do
    queries = []
    
    # Collect queries during dashboard load
    subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
      duration = (finish - start) * 1000
      queries << { sql: payload[:sql], duration_ms: duration.round(2) }
    end
    
    # Simulate dashboard request
    user = create(:user)
    get dashboard_path, headers: { 'Authorization' => "Bearer #{user.auth_token}" }
    
    # Analyze performance
    result = optimizer.analyze_queries(queries)
    
    expect(result['success']).to be true
    expect(result['data']['summary']['optimization_score']).to be >= 80
    expect(result['data']['n_plus_one']['detected']).to be false
    
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end
  
  it "detects performance regressions in search" do
    queries = [
      { sql: "SELECT * FROM products WHERE name ILIKE '%search%'", duration_ms: 150 },
      { sql: "SELECT * FROM products WHERE category_id = 1", duration_ms: 80 }
    ]
    
    result = optimizer.check_ci_quality(queries, 85)
    expect(result).to be true
  end
end
```

### Example 3: Custom Performance Monitoring

```ruby
# app/services/performance_monitor.rb
class PerformanceMonitor
  def self.monitor_endpoint(endpoint_name)
    queries = []
    start_time = Time.current
    
    subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
      duration = (finish - start) * 1000
      queries << {
        sql: payload[:sql],
        duration_ms: duration.round(2)
      }
    end
    
    yield
    
    total_time = (Time.current - start_time) * 1000
    
    # Analyze queries
    optimizer = QueryOptimizerService.new
    result = optimizer.analyze_queries(queries)
    
    # Store metrics
    PerformanceMetric.create!(
      endpoint: endpoint_name,
      total_duration_ms: total_time,
      query_count: queries.length,
      optimization_score: result.dig('data', 'summary', 'optimization_score'),
      issues_found: result.dig('data', 'summary', 'issues_found'),
      analysis_data: result['data']
    )
    
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end
end

# Usage in controllers
class PostsController < ApplicationController
  def index
    PerformanceMonitor.monitor_endpoint('posts#index') do
      @posts = Post.includes(:user, :comments).limit(20)
    end
  end
end
```

## Performance Monitoring

### Example 1: Real-time Dashboard

```ruby
# app/controllers/admin/performance_controller.rb
class Admin::PerformanceController < ApplicationController
  def dashboard
    @current_score = QueryOptimizationResult.recent.average(:optimization_score)
    @trend_data = QueryOptimizationResult.trend_data
    @recent_issues = QueryOptimizationResult.recent.where('issues_found > 0').limit(10)
  end
  
  def analyze_current
    # Collect recent queries from logs or active monitoring
    queries = collect_recent_queries
    
    optimizer = QueryOptimizerService.new
    @result = optimizer.analyze_queries(queries)
    
    render json: @result
  end
  
  private
  
  def collect_recent_queries
    # Implementation depends on your logging setup
    # This is a simplified example
    Rails.cache.fetch('recent_queries', expires_in: 5.minutes) do
      [
        { sql: "SELECT * FROM users WHERE active = true", duration_ms: 45 },
        { sql: "SELECT * FROM posts WHERE created_at > '2024-01-01'", duration_ms: 120 }
      ]
    end
  end
end
```

### Example 2: Automated Alerts

```ruby
# app/jobs/performance_check_job.rb
class PerformanceCheckJob < ApplicationJob
  queue_as :default
  
  def perform
    queries = collect_representative_queries
    optimizer = QueryOptimizerService.new
    result = optimizer.analyze_queries(queries)
    
    return unless result&.dig('success')
    
    data = result['data']
    score = data['summary']['optimization_score']
    
    if score < 60
      send_critical_alert(data)
    elsif score < 75
      send_warning_alert(data)
    end
    
    # Store result for trending
    QueryOptimizationResult.create!(
      optimization_score: score,
      issues_found: data['summary']['issues_found'],
      total_queries: data['summary']['total_queries'],
      analysis_data: data,
      analyzed_at: Time.current
    )
  end
  
  private
  
  def collect_representative_queries
    # Collect from various sources
    [
      *user_queries,
      *post_queries,
      *search_queries
    ]
  end
  
  def send_critical_alert(data)
    SlackNotifier.ping(
      "🚨 CRITICAL: Query performance score dropped to #{data['summary']['optimization_score']}%",
      channel: '#alerts'
    )
  end
  
  def send_warning_alert(data)
    SlackNotifier.ping(
      "⚠️ WARNING: Query performance score is #{data['summary']['optimization_score']}%",
      channel: '#performance'
    )
  end
end

# Schedule the job
# config/schedule.rb (using whenever gem)
every 1.hour do
  runner "PerformanceCheckJob.perform_later"
end
```

### Example 3: Performance Regression Detection

```ruby
# spec/performance/regression_spec.rb
RSpec.describe "Performance Regression Detection" do
  let(:optimizer) { QueryOptimizerService.new }
  
  context "user dashboard performance" do
    it "maintains baseline performance" do
      baseline_score = 85
      
      queries = simulate_dashboard_queries
      result = optimizer.analyze_queries(queries)
      
      current_score = result.dig('data', 'summary', 'optimization_score')
      
      expect(current_score).to be >= baseline_score,
        "Performance regression detected: #{current_score} < #{baseline_score}"
    end
  end
  
  context "search functionality" do
    it "search queries remain optimized" do
      search_queries = [
        { sql: "SELECT * FROM products WHERE name ILIKE '%laptop%'", duration_ms: 120 },
        { sql: "SELECT * FROM products WHERE category_id = 1 ORDER BY price", duration_ms: 80 }
      ]
      
      result = optimizer.analyze_queries(search_queries)
      
      expect(result.dig('data', 'n_plus_one', 'detected')).to be false
      expect(result.dig('data', 'slow_queries')).to be_empty
    end
  end
  
  private
  
  def simulate_dashboard_queries
    user = create(:user)
    
    [
      { sql: User.includes(:posts).find(user.id).to_sql, duration_ms: 50 },
      { sql: user.posts.recent.to_sql, duration_ms: 80 },
      { sql: user.notifications.unread.to_sql, duration_ms: 30 }
    ]
  end
end
```

These examples demonstrate practical, real-world usage of the Query Optimizer API for detecting and fixing common Rails performance issues. Each example includes the problematic code, API analysis results, and optimized solutions.
