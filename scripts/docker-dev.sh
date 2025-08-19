#!/bin/bash

# Docker Development Script for Query Optimizer API
# This script sets up a development environment with live reloading

set -e

echo "🛠️  Query Optimizer API - Development Setup"
echo "==========================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Create master key if it doesn't exist
if [ ! -f config/master.key ]; then
    echo "🔑 Generating Rails master key..."
    openssl rand -hex 32 > config/master.key
    echo "✅ Master key created"
fi

# Start development services
echo "🚀 Starting development services..."
docker-compose -f docker-compose.dev.yml up --build -d

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
until docker-compose -f docker-compose.dev.yml exec -T db pg_isready -U postgres > /dev/null 2>&1; do
    sleep 2
done

echo "✅ Database is ready!"

# Setup database
echo "📊 Setting up database..."
docker-compose -f docker-compose.dev.yml exec -T app ./bin/rails db:create db:migrate

# Create sample API key
echo "🔑 Creating development API key..."
API_KEY=$(docker-compose -f docker-compose.dev.yml exec -T app ./bin/rails runner "
app = AppProfile.find_or_create_by(name: 'Development')
puts app.generate_api_key!
" 2>/dev/null | tail -1)

echo ""
echo "🎉 Development Environment Ready!"
echo "================================"
echo "🌐 API URL: http://localhost:3000"
echo "🔑 API Key: $API_KEY"
echo "📊 Database: postgresql://postgres:password@localhost:5432/query_optimizer_development"
echo "🔴 Redis: redis://localhost:6379"
echo ""
echo "📋 Useful Commands:"
echo "🔍 View logs: docker-compose -f docker-compose.dev.yml logs -f app"
echo "🐚 Rails console: docker-compose -f docker-compose.dev.yml exec app ./bin/rails console"
echo "🧪 Run tests: docker-compose -f docker-compose.dev.yml exec app ./bin/rails test"
echo "🛑 Stop services: docker-compose -f docker-compose.dev.yml down"
echo ""
echo "📋 Quick Test:"
echo "curl -X POST http://localhost:3000/api/v1/analyze \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -H 'X-API-Key: $API_KEY' \\"
echo "  -d '{\"queries\":[{\"sql\":\"SELECT 1\",\"duration_ms\":10}]}'"

# Follow logs
echo ""
echo "📋 Following application logs (Ctrl+C to stop)..."
docker-compose -f docker-compose.dev.yml logs -f app
