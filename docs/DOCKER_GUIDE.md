# Docker Deployment Guide

Complete guide for running the Query Optimizer API with Docker.

## Quick Start

### 🚀 **One-Command Setup**

```bash
# For development
./scripts/docker-dev.sh

# For production
./scripts/docker-deploy.sh
```

## Prerequisites

- **Docker**: [Install Docker](https://docs.docker.com/get-docker/)
- **Docker Compose**: [Install Docker Compose](https://docs.docker.com/compose/install/)

## Development Setup

### 1. Start Development Environment

```bash
# Start with live code reloading
docker-compose -f docker-compose.dev.yml up --build
```

This starts:
- **Rails API** on `http://localhost:3000`
- **PostgreSQL** on `localhost:5432`
- **Redis** on `localhost:6379`

### 2. Setup Database

```bash
# Create and migrate database
docker-compose -f docker-compose.dev.yml exec app rails db:create db:migrate

# Create API key
docker-compose -f docker-compose.dev.yml exec app rails runner "
  app = AppProfile.create!(name: 'Development')
  puts 'API Key: ' + app.generate_api_key!
"
```

### 3. Test the API

```bash
curl -X POST http://localhost:3000/api/v1/analyze \
  -H 'Content-Type: application/json' \
  -H 'X-API-Key: your_api_key_here' \
  -d '{"queries":[{"sql":"SELECT 1","duration_ms":10}]}'
```

## Production Deployment

### 1. Build Production Image

```bash
# Build optimized production image
docker build -t query-optimizer-api:latest .
```

### 2. Start Production Services

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps
```

### 3. Initialize Database

```bash
# Database is automatically initialized via entrypoint
# Check logs to confirm
docker-compose logs app
```

## Configuration

### Environment Variables

Create a `.env` file for production:

```bash
# .env
RAILS_ENV=production
DATABASE_URL=postgresql://postgres:password@db:5432/query_optimizer_production
REDIS_URL=redis://redis:6379/0

# Security
SECRET_KEY_BASE=your_secret_key_base_here
RAILS_MASTER_KEY=your_master_key_here

# API Configuration
API_RATE_LIMIT=1000
API_RATE_LIMIT_WINDOW=3600
```

### Docker Compose Override

Create `docker-compose.override.yml` for custom settings:

```yaml
version: '3.8'

services:
  app:
    environment:
      - CUSTOM_ENV_VAR=value
    ports:
      - "8080:80"  # Custom port
    
  db:
    environment:
      - POSTGRES_PASSWORD=your_secure_password
```

## Useful Commands

### Development

```bash
# Start development environment
docker-compose -f docker-compose.dev.yml up

# Rails console
docker-compose -f docker-compose.dev.yml exec app rails console

# Run tests
docker-compose -f docker-compose.dev.yml exec app rspec

# View logs
docker-compose -f docker-compose.dev.yml logs -f app

# Stop services
docker-compose -f docker-compose.dev.yml down
```

### Production

```bash
# Start production services
docker-compose up -d

# View logs
docker-compose logs -f

# Scale app instances
docker-compose up -d --scale app=3

# Update application
docker-compose pull
docker-compose up -d

# Stop services
docker-compose down
```

### Database Management

```bash
# Connect to database
docker-compose exec db psql -U postgres -d query_optimizer_production

# Backup database
docker-compose exec db pg_dump -U postgres query_optimizer_production > backup.sql

# Restore database
docker-compose exec -T db psql -U postgres -d query_optimizer_production < backup.sql

# Reset database
docker-compose exec app rails db:drop db:create db:migrate
```

## Monitoring

### Health Checks

```bash
# Check API health
curl http://localhost:3000/api/v1/health

# Check container health
docker-compose ps
```

### Logs

```bash
# Follow all logs
docker-compose logs -f

# Follow specific service
docker-compose logs -f app

# View recent logs
docker-compose logs --tail=100 app
```

### Resource Usage

```bash
# View resource usage
docker stats

# View container details
docker-compose exec app top
```

## Deployment to Cloud

### Docker Hub

```bash
# Build and tag
docker build -t yourusername/query-optimizer-api:latest .

# Push to Docker Hub
docker push yourusername/query-optimizer-api:latest
```

### Railway

```bash
# Deploy to Railway
railway login
railway init
railway up
```

### Render

Create `render.yaml`:

```yaml
services:
  - type: web
    name: query-optimizer-api
    env: docker
    dockerfilePath: ./Dockerfile
    envVars:
      - key: RAILS_ENV
        value: production
      - key: DATABASE_URL
        fromDatabase:
          name: query-optimizer-db
          property: connectionString

databases:
  - name: query-optimizer-db
    databaseName: query_optimizer_production
```

### Google Cloud Run

```bash
# Build and push to Google Container Registry
docker build -t gcr.io/your-project/query-optimizer-api .
docker push gcr.io/your-project/query-optimizer-api

# Deploy to Cloud Run
gcloud run deploy query-optimizer-api \
  --image gcr.io/your-project/query-optimizer-api \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

## Troubleshooting

### Common Issues

**Database Connection Failed:**
```bash
# Check if database is running
docker-compose ps db

# Check database logs
docker-compose logs db

# Restart database
docker-compose restart db
```

**Permission Denied:**
```bash
# Fix file permissions
sudo chown -R $USER:$USER .
chmod +x scripts/*.sh
```

**Out of Disk Space:**
```bash
# Clean up Docker
docker system prune -a

# Remove unused volumes
docker volume prune
```

**Port Already in Use:**
```bash
# Find process using port
lsof -i :3000

# Kill process
kill -9 <PID>

# Or use different port
docker-compose up -p 8080:80
```

### Debug Mode

```bash
# Run with debug output
docker-compose up --verbose

# Enter container for debugging
docker-compose exec app bash

# Check environment variables
docker-compose exec app env
```

## Security Considerations

### Production Security

1. **Use secrets for sensitive data:**
```yaml
secrets:
  rails_master_key:
    file: ./config/master.key
  database_password:
    external: true
```

2. **Run as non-root user:**
```dockerfile
USER 1000:1000
```

3. **Limit container resources:**
```yaml
deploy:
  resources:
    limits:
      memory: 512M
      cpus: '0.5'
```

4. **Use health checks:**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

This Docker setup provides a robust, scalable deployment solution for the Query Optimizer API! 🐳
