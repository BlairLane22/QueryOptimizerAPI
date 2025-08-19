#!/bin/bash

# Docker Deployment Script for Query Optimizer API
# This script builds and deploys the API for production use

set -e

echo "🚀 Query Optimizer API - Production Deployment"
echo "=============================================="

# Build the production image
echo "📦 Building production Docker image..."
docker build -t query-optimizer-api:latest .

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose down || true

# Start production services
echo "🚀 Starting production services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check health
echo "🔍 Checking API health..."
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -f http://localhost:3000/api/v1/health > /dev/null 2>&1; then
        echo "✅ API is healthy and ready!"
        break
    else
        echo "⏳ Attempt $attempt/$max_attempts - API not ready yet..."
        sleep 5
        ((attempt++))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    echo "❌ API failed to become healthy within expected time"
    echo "📋 Checking logs..."
    docker-compose logs app
    exit 1
fi

# Create initial API key
echo "🔑 Creating initial API key..."
API_KEY=$(docker-compose exec -T app ./bin/rails runner "
app = AppProfile.find_or_create_by(name: 'Docker Deployment')
puts app.generate_api_key!
" 2>/dev/null | tail -1)

echo ""
echo "🎉 Deployment Complete!"
echo "======================"
echo "🌐 API URL: http://localhost:3000"
echo "🔑 API Key: $API_KEY"
echo ""
echo "📋 Quick Test:"
echo "curl -X POST http://localhost:3000/api/v1/analyze \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -H 'X-API-Key: $API_KEY' \\"
echo "  -d '{\"queries\":[{\"sql\":\"SELECT 1\",\"duration_ms\":10}]}'"
echo ""
echo "📊 View logs: docker-compose logs -f"
echo "🛑 Stop services: docker-compose down"
