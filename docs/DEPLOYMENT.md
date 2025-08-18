# Deployment Guide

Complete guide for deploying the Rails Database Query Optimizer API to production.

## Table of Contents

1. [Production Requirements](#production-requirements)
2. [Environment Configuration](#environment-configuration)
3. [Database Setup](#database-setup)
4. [Docker Deployment](#docker-deployment)
5. [Heroku Deployment](#heroku-deployment)
6. [AWS Deployment](#aws-deployment)
7. [Monitoring and Logging](#monitoring-and-logging)
8. [Security Considerations](#security-considerations)

## Production Requirements

### System Requirements

- **Ruby**: 3.2.0 or higher
- **Rails**: 7.1.0 or higher
- **Database**: PostgreSQL 13+ (required for JSON support and pg_query gem)
- **Memory**: Minimum 512MB RAM, recommended 1GB+
- **CPU**: 1+ cores, 2+ cores recommended for high traffic
- **Storage**: 10GB+ for logs and database

### Dependencies

```ruby
# Production gems
gem 'pg', '~> 1.1'
gem 'puma', '~> 6.0'
gem 'redis', '~> 5.0'
gem 'bootsnap', '>= 1.4.4', require: false
gem 'image_processing', '~> 1.2'

# Monitoring and logging
gem 'newrelic_rpm'
gem 'sentry-ruby'
gem 'sentry-rails'

# Performance
gem 'rack-timeout'
gem 'rack-attack'
```

## Environment Configuration

### Environment Variables

Create a `.env.production` file:

```bash
# Application
RAILS_ENV=production
RACK_ENV=production
PORT=3000

# Database
DATABASE_URL=postgresql://username:password@host:port/database_name

# Security
SECRET_KEY_BASE=your_very_long_secret_key_here
RAILS_MASTER_KEY=your_master_key_here

# Redis (for caching and rate limiting)
REDIS_URL=redis://localhost:6379/0

# API Configuration
API_RATE_LIMIT=1000
API_RATE_LIMIT_WINDOW=3600

# Monitoring
NEW_RELIC_LICENSE_KEY=your_newrelic_key
SENTRY_DSN=your_sentry_dsn

# Logging
LOG_LEVEL=info
RAILS_LOG_TO_STDOUT=true

# Performance
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2
```

### Production Configuration

```ruby
# config/environments/production.rb
Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  
  # Logging
  config.log_level = ENV.fetch('LOG_LEVEL', 'info').to_sym
  config.log_tags = [:request_id]
  
  # Caching
  config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }
  
  # Security
  config.force_ssl = true
  config.ssl_options = { redirect: { exclude: ->(request) { request.path =~ /health/ } } }
  
  # CORS
  config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins '*'
      resource '/api/*',
        headers: :any,
        methods: [:get, :post, :put, :patch, :delete, :options, :head],
        expose: ['X-RateLimit-Limit', 'X-RateLimit-Remaining', 'X-RateLimit-Reset']
    end
  end
  
  # Rate limiting
  config.middleware.use Rack::Attack
  
  # Timeouts
  config.middleware.use Rack::Timeout, service_timeout: 30
end
```

### Rate Limiting Configuration

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # Rate limit by API key
  throttle('api_requests_by_key', limit: ENV.fetch('API_RATE_LIMIT', 1000).to_i, period: ENV.fetch('API_RATE_LIMIT_WINDOW', 3600).to_i) do |req|
    req.env['HTTP_X_API_KEY'] if req.path.start_with?('/api/')
  end
  
  # Rate limit by IP for API key creation
  throttle('api_key_creation_by_ip', limit: 10, period: 1.hour) do |req|
    req.ip if req.path == '/api/v1/api_keys' && req.post?
  end
  
  # Block requests with invalid API keys after too many attempts
  blocklist('block_invalid_api_keys') do |req|
    Rack::Attack::Allow2Ban.filter(req.env['HTTP_X_API_KEY'], maxretry: 5, findtime: 10.minutes, bantime: 1.hour) do
      # This block is called when the API key fails authentication
      req.env['rack.attack.invalid_api_key'] == true
    end
  end
end
```

## Database Setup

### Production Database Configuration

```yaml
# config/database.yml
production:
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  url: <%= ENV['DATABASE_URL'] %>
  prepared_statements: false
  advisory_locks: false
```

### Database Migrations

```bash
# Run migrations
RAILS_ENV=production bundle exec rails db:migrate

# Create initial admin API key
RAILS_ENV=production bundle exec rails runner "
  app = AppProfile.create!(name: 'Admin')
  key = app.generate_api_key!
  puts 'Admin API Key: ' + key
"
```

### Database Optimization

```sql
-- Add database-level optimizations
-- config/initializers/database.rb

ActiveRecord::Base.connection.execute <<-SQL
  -- Optimize PostgreSQL for query analysis workload
  ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
  ALTER SYSTEM SET pg_stat_statements.track = 'all';
  ALTER SYSTEM SET log_min_duration_statement = 1000;
  ALTER SYSTEM SET log_statement = 'mod';
SQL
```

## Docker Deployment

### Dockerfile

```dockerfile
FROM ruby:3.2-alpine

# Install dependencies
RUN apk add --no-cache \
  build-base \
  postgresql-dev \
  nodejs \
  yarn \
  git \
  tzdata

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle config --global frozen 1 && \
    bundle install --without development test

# Copy application code
COPY . .

# Precompile assets (if any)
RUN bundle exec rails assets:precompile

# Create non-root user
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup
USER appuser

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/api/v1/health || exit 1

# Start server
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/query_optimizer_production
      - REDIS_URL=redis://redis:6379/0
      - RAILS_ENV=production
    depends_on:
      - db
      - redis
    volumes:
      - ./log:/app/log
    restart: unless-stopped

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=query_optimizer_production
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - app
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```

### Nginx Configuration

```nginx
# nginx.conf
events {
    worker_connections 1024;
}

http {
    upstream app {
        server app:3000;
    }

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

    server {
        listen 80;
        server_name your-domain.com;
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name your-domain.com;

        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;

        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";

        location /api/ {
            limit_req zone=api burst=20 nodelay;
            
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Timeouts
            proxy_connect_timeout 5s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }

        location /health {
            proxy_pass http://app;
            access_log off;
        }
    }
}
```

## Heroku Deployment

### Heroku Setup

```bash
# Install Heroku CLI and login
heroku login

# Create application
heroku create your-query-optimizer-api

# Add PostgreSQL addon
heroku addons:create heroku-postgresql:mini

# Add Redis addon
heroku addons:create heroku-redis:mini

# Set environment variables
heroku config:set RAILS_ENV=production
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)
heroku config:set API_RATE_LIMIT=1000

# Deploy
git push heroku main

# Run migrations
heroku run rails db:migrate

# Create admin API key
heroku run rails runner "
  app = AppProfile.create!(name: 'Admin')
  key = app.generate_api_key!
  puts 'Admin API Key: ' + key
"
```

### Procfile

```
# Procfile
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
```

### Heroku Configuration

```ruby
# config/puma.rb (Heroku optimized)
workers ENV.fetch("WEB_CONCURRENCY") { 2 }
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

preload_app!

rackup      DefaultRackup
port        ENV.fetch("PORT") { 3000 }
environment ENV.fetch("RAILS_ENV") { "development" }

on_worker_boot do
  ActiveRecord::Base.establish_connection
end
```

## AWS Deployment

### Elastic Beanstalk

```yaml
# .ebextensions/01_packages.config
packages:
  yum:
    postgresql-devel: []
    git: []

# .ebextensions/02_ruby.config
option_settings:
  aws:elasticbeanstalk:application:environment:
    RAILS_ENV: production
    RACK_ENV: production
    BUNDLE_WITHOUT: "development:test"
  aws:elasticbeanstalk:container:ruby:
    RubyVersion: "3.2"
    BundlerVersion: "2.4.0"

# .ebextensions/03_database.config
option_settings:
  aws:elasticbeanstalk:application:environment:
    DATABASE_URL: "postgresql://username:password@your-rds-endpoint:5432/database"
```

### ECS Deployment

```yaml
# ecs-task-definition.json
{
  "family": "query-optimizer-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::account:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "query-optimizer-api",
      "image": "your-account.dkr.ecr.region.amazonaws.com/query-optimizer-api:latest",
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "RAILS_ENV",
          "value": "production"
        },
        {
          "name": "DATABASE_URL",
          "value": "postgresql://username:password@rds-endpoint:5432/database"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/query-optimizer-api",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:3000/api/v1/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

## Monitoring and Logging

### Application Monitoring

```ruby
# config/initializers/monitoring.rb

# New Relic
if ENV['NEW_RELIC_LICENSE_KEY']
  require 'newrelic_rpm'
end

# Sentry
if ENV['SENTRY_DSN']
  Sentry.init do |config|
    config.dsn = ENV['SENTRY_DSN']
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
    config.traces_sample_rate = 0.1
  end
end

# Custom metrics
class ApplicationMetrics
  def self.track_api_request(endpoint, duration, status)
    StatsD.increment('api.requests.total', tags: ["endpoint:#{endpoint}", "status:#{status}"])
    StatsD.histogram('api.requests.duration', duration, tags: ["endpoint:#{endpoint}"])
  end
  
  def self.track_query_analysis(score, issues_count)
    StatsD.histogram('query_analysis.score', score)
    StatsD.histogram('query_analysis.issues', issues_count)
  end
end
```

### Logging Configuration

```ruby
# config/initializers/logging.rb
if Rails.env.production?
  # Structured logging
  Rails.application.configure do
    config.log_formatter = proc do |severity, timestamp, progname, msg|
      {
        timestamp: timestamp.iso8601,
        level: severity,
        message: msg,
        service: 'query-optimizer-api',
        version: ENV['APP_VERSION']
      }.to_json + "\n"
    end
  end
  
  # Log API requests
  Rails.application.config.middleware.use(Rack::CommonLogger, Rails.logger)
end
```

### Health Checks

```ruby
# config/initializers/health_checks.rb
Rails.application.routes.draw do
  # Kubernetes/Docker health checks
  get '/health/live', to: proc { [200, {}, ['OK']] }
  get '/health/ready', to: 'health#ready'
end

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def ready
    checks = {
      database: check_database,
      redis: check_redis,
      external_apis: check_external_apis
    }
    
    if checks.values.all? { |status| status == 'ok' }
      render json: { status: 'ready', checks: checks }
    else
      render json: { status: 'not_ready', checks: checks }, status: 503
    end
  end
  
  private
  
  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    'ok'
  rescue
    'error'
  end
  
  def check_redis
    Redis.current.ping
    'ok'
  rescue
    'error'
  end
  
  def check_external_apis
    # Check any external dependencies
    'ok'
  end
end
```

## Security Considerations

### SSL/TLS Configuration

```ruby
# config/environments/production.rb
config.force_ssl = true
config.ssl_options = {
  secure_cookies: true,
  hsts: {
    expires: 1.year,
    subdomains: true,
    preload: true
  }
}
```

### API Security

```ruby
# app/controllers/api/v1/base_controller.rb
class Api::V1::BaseController < ApplicationController
  before_action :authenticate_api_key
  before_action :check_rate_limit
  before_action :validate_content_type
  
  private
  
  def validate_content_type
    return if request.get? || request.delete?
    
    unless request.content_type == 'application/json'
      render_error('Content-Type must be application/json', :bad_request)
    end
  end
  
  def secure_headers
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
  end
end
```

### Environment Security

```bash
# Use secrets management
export DATABASE_URL=$(aws ssm get-parameter --name "/app/database-url" --with-decryption --query "Parameter.Value" --output text)
export SECRET_KEY_BASE=$(aws ssm get-parameter --name "/app/secret-key-base" --with-decryption --query "Parameter.Value" --output text)

# Rotate API keys regularly
bundle exec rails runner "
  AppProfile.find_each do |app|
    if app.updated_at < 90.days.ago
      puts \"Rotating API key for #{app.name}\"
      app.generate_api_key!
    end
  end
"
```

### Backup Strategy

```bash
#!/bin/bash
# scripts/backup.sh

# Database backup
pg_dump $DATABASE_URL | gzip > "backup-$(date +%Y%m%d-%H%M%S).sql.gz"

# Upload to S3
aws s3 cp backup-*.sql.gz s3://your-backup-bucket/database/

# Cleanup old backups (keep 30 days)
find . -name "backup-*.sql.gz" -mtime +30 -delete
```

This deployment guide covers the essential aspects of deploying the Query Optimizer API to production environments with proper security, monitoring, and scalability considerations.
