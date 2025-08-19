# QueryWise Installation Guide

## 💎 Install from RubyGems

```bash
gem install QueryWise
```

Or add to your Gemfile:

```ruby
gem 'QueryWise'
```

## 🚀 Quick Setup

### 1. Generate Configuration

```bash
rails generate QueryWise:install
```

### 2. Configure API Connection

Add to your `.env` file:

```bash
QUERY_OPTIMIZER_API_URL=https://your-hosted-api.com/api/v1
QUERY_OPTIMIZER_API_KEY=your_api_key_here
QUERY_OPTIMIZER_ENABLED=true
```

### 3. Test Your Setup

```bash
rails query_optimizer:check
```

## 📋 Usage Examples

### Basic Analysis

```ruby
queries = [
  { sql: "SELECT * FROM users WHERE id = 1", duration_ms: 50 }
]

result = QueryOptimizerClient.analyze_queries(queries)
puts "Score: #{result['data']['summary']['optimization_score']}%"
```

### CI Integration

```bash
rails query_optimizer:ci[85]
```

## 🔗 Links

- **RubyGems**: https://rubygems.org/gems/QueryWise
- **GitHub**: https://github.com/BlairLane22/QueryWise
- **Documentation**: See README.md for complete guide

## 📞 Support

- **Issues**: https://github.com/BlairLane22/QueryWise/issues
- **Discussions**: https://github.com/BlairLane22/QueryWise/discussions
