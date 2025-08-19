# 🐳 Docker Deployment - Query Optimizer API

Get the Query Optimizer API running with Docker in minutes!

## 🚀 Quick Start

### Option 1: Automated Setup (Recommended)

```bash
# Development environment with live reloading
./scripts/docker-dev.sh

# Production environment
./scripts/docker-deploy.sh
```

### Option 2: Manual Setup

```bash
# 1. Start services
docker-compose up --build -d

# 2. Test the deployment
./scripts/test-docker.sh
```

## 📋 What You Get

- ✅ **Rails API** running on port 3000
- ✅ **PostgreSQL** database with automatic setup
- ✅ **Redis** for caching and rate limiting
- ✅ **Health checks** and monitoring
- ✅ **Automatic database migrations**
- ✅ **Production-ready configuration**

## 🛠️ Development vs Production

### Development Mode
```bash
# Start development environment
docker-compose -f docker-compose.dev.yml up --build

# Features:
# - Live code reloading
# - Development gems included
# - Detailed logging
# - Easy debugging
```

### Production Mode
```bash
# Start production environment
docker-compose up --build -d

# Features:
# - Optimized multi-stage build
# - Minimal image size
# - Security hardening
# - Performance optimizations
```

## 🔧 Configuration

### Environment Variables

Create a `.env` file:

```bash
# Database
DATABASE_URL=postgresql://postgres:password@db:5432/query_optimizer_production

# Security
RAILS_MASTER_KEY=your_master_key_here
SECRET_KEY_BASE=your_secret_key_here

# API Settings
API_RATE_LIMIT=1000
API_RATE_LIMIT_WINDOW=3600
```

### Custom Configuration

Create `docker-compose.override.yml`:

```yaml
version: '3.8'
services:
  app:
    ports:
      - "8080:80"  # Custom port
    environment:
      - CUSTOM_SETTING=value
```

## 📊 Usage Examples

### 1. Get API Key

```bash
# Create API key
docker-compose exec app rails runner "
  app = AppProfile.create!(name: 'My App')
  puts 'API Key: ' + app.generate_api_key!
"
```

### 2. Test the API

```bash
# Health check
curl http://localhost:3000/api/v1/health

# Analyze queries
curl -X POST http://localhost:3000/api/v1/analyze \
  -H 'Content-Type: application/json' \
  -H 'X-API-Key: your_api_key_here' \
  -d '{
    "queries": [
      {
        "sql": "SELECT * FROM users WHERE id = 1",
        "duration_ms": 50
      }
    ]
  }'
```

### 3. CI Integration

```bash
# Test CI endpoint
curl -X POST http://localhost:3000/api/v1/analyze_ci \
  -H 'Content-Type: application/json' \
  -H 'X-API-Key: your_api_key_here' \
  -d '{
    "queries": [{"sql": "SELECT 1", "duration_ms": 10}],
    "threshold_score": 80
  }'
```

## 🔍 Monitoring

### Health Checks

```bash
# Check service status
docker-compose ps

# Check API health
curl http://localhost:3000/api/v1/health

# View logs
docker-compose logs -f app
```

### Resource Usage

```bash
# Monitor resource usage
docker stats

# Check container details
docker-compose exec app top
```

## 🚀 Deployment Options

### 1. Railway

```bash
# Deploy to Railway
railway login
railway init
railway up
```

### 2. Render

```yaml
# render.yaml
services:
  - type: web
    name: query-optimizer-api
    env: docker
    dockerfilePath: ./Dockerfile
```

### 3. Google Cloud Run

```bash
# Build and deploy
docker build -t gcr.io/project/query-optimizer-api .
docker push gcr.io/project/query-optimizer-api
gcloud run deploy --image gcr.io/project/query-optimizer-api
```

### 4. AWS ECS

```bash
# Push to ECR
aws ecr get-login-password | docker login --username AWS --password-stdin
docker build -t query-optimizer-api .
docker tag query-optimizer-api:latest account.dkr.ecr.region.amazonaws.com/query-optimizer-api:latest
docker push account.dkr.ecr.region.amazonaws.com/query-optimizer-api:latest
```

## 🛠️ Useful Commands

### Development

```bash
# Rails console
docker-compose -f docker-compose.dev.yml exec app rails console

# Run tests
docker-compose -f docker-compose.dev.yml exec app rspec

# Generate migration
docker-compose -f docker-compose.dev.yml exec app rails generate migration AddIndexToUsers

# Run migration
docker-compose -f docker-compose.dev.yml exec app rails db:migrate
```

### Production

```bash
# Scale application
docker-compose up -d --scale app=3

# Update application
docker-compose pull
docker-compose up -d

# Backup database
docker-compose exec db pg_dump -U postgres query_optimizer_production > backup.sql

# View application logs
docker-compose logs -f app
```

### Debugging

```bash
# Enter container
docker-compose exec app bash

# Check environment
docker-compose exec app env

# Debug database connection
docker-compose exec app rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1')"
```

## 🔒 Security

### Production Security Checklist

- ✅ **Non-root user**: Containers run as user 1000
- ✅ **Secrets management**: Master key stored as Docker secret
- ✅ **Health checks**: Automatic container health monitoring
- ✅ **Resource limits**: Memory and CPU limits configured
- ✅ **Network isolation**: Services communicate via internal network
- ✅ **Minimal image**: Multi-stage build reduces attack surface

### Security Best Practices

```yaml
# docker-compose.yml security example
services:
  app:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp
      - /rails/tmp
```

## 🐛 Troubleshooting

### Common Issues

**Port already in use:**
```bash
# Find and kill process
lsof -i :3000
kill -9 <PID>
```

**Database connection failed:**
```bash
# Check database status
docker-compose ps db
docker-compose logs db

# Restart database
docker-compose restart db
```

**Permission denied:**
```bash
# Fix permissions
sudo chown -R $USER:$USER .
chmod +x scripts/*.sh
```

**Out of disk space:**
```bash
# Clean up Docker
docker system prune -a
docker volume prune
```

## 📞 Support

- 📖 **Full Documentation**: See `docs/DOCKER_GUIDE.md`
- 🐛 **Issues**: Report issues on GitHub
- 💬 **Discussions**: Join our community discussions

---

**Ready to deploy?** Run `./scripts/docker-deploy.sh` and you'll have a production-ready Query Optimizer API running in minutes! 🚀
