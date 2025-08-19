#!/bin/bash

# Test Docker Setup for Query Optimizer API
# This script tests that the Docker deployment is working correctly

set -e

echo "🧪 Testing Query Optimizer API Docker Setup"
echo "==========================================="

# Check if services are running
echo "🔍 Checking if services are running..."

if ! docker-compose ps | grep -q "Up"; then
    echo "❌ Services are not running. Please start them first:"
    echo "   docker-compose up -d"
    exit 1
fi

echo "✅ Services are running"

# Wait for API to be ready
echo "⏳ Waiting for API to be ready..."
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -f http://localhost:3000/api/v1/health > /dev/null 2>&1; then
        echo "✅ API is responding"
        break
    else
        echo "⏳ Attempt $attempt/$max_attempts - waiting for API..."
        sleep 2
        ((attempt++))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    echo "❌ API failed to respond within expected time"
    exit 1
fi

# Test health endpoint
echo "🔍 Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s http://localhost:3000/api/v1/health)
echo "Health response: $HEALTH_RESPONSE"

if echo "$HEALTH_RESPONSE" | grep -q '"status":"ok"'; then
    echo "✅ Health endpoint working"
else
    echo "❌ Health endpoint failed"
    exit 1
fi

# Get or create API key
echo "🔑 Getting API key..."
API_KEY=$(docker-compose exec -T app ./bin/rails runner "
app = AppProfile.find_or_create_by(name: 'Test')
puts app.generate_api_key!
" 2>/dev/null | tail -1)

if [ -z "$API_KEY" ]; then
    echo "❌ Failed to get API key"
    exit 1
fi

echo "✅ API key obtained: ${API_KEY:0:16}..."

# Test analyze endpoint
echo "🔍 Testing analyze endpoint..."
ANALYZE_RESPONSE=$(curl -s -X POST http://localhost:3000/api/v1/analyze \
  -H 'Content-Type: application/json' \
  -H "X-API-Key: $API_KEY" \
  -d '{"queries":[{"sql":"SELECT * FROM users WHERE id = 1","duration_ms":50}]}')

echo "Analyze response: $ANALYZE_RESPONSE"

if echo "$ANALYZE_RESPONSE" | grep -q '"success":true'; then
    echo "✅ Analyze endpoint working"
else
    echo "❌ Analyze endpoint failed"
    echo "Response: $ANALYZE_RESPONSE"
    exit 1
fi

# Test CI endpoint
echo "🔍 Testing CI endpoint..."
CI_RESPONSE=$(curl -s -X POST http://localhost:3000/api/v1/analyze_ci \
  -H 'Content-Type: application/json' \
  -H "X-API-Key: $API_KEY" \
  -d '{"queries":[{"sql":"SELECT 1","duration_ms":10}],"threshold_score":80}')

echo "CI response: $CI_RESPONSE"

if echo "$CI_RESPONSE" | grep -q '"success":true'; then
    echo "✅ CI endpoint working"
else
    echo "❌ CI endpoint failed"
    echo "Response: $CI_RESPONSE"
    exit 1
fi

# Test invalid API key
echo "🔍 Testing authentication..."
AUTH_RESPONSE=$(curl -s -X POST http://localhost:3000/api/v1/analyze \
  -H 'Content-Type: application/json' \
  -H "X-API-Key: invalid_key" \
  -d '{"queries":[{"sql":"SELECT 1","duration_ms":10}]}')

if echo "$AUTH_RESPONSE" | grep -q '"success":false'; then
    echo "✅ Authentication working (correctly rejected invalid key)"
else
    echo "❌ Authentication failed (should reject invalid key)"
    exit 1
fi

echo ""
echo "🎉 All tests passed!"
echo "==================="
echo "✅ Health endpoint working"
echo "✅ API key generation working"
echo "✅ Query analysis working"
echo "✅ CI integration working"
echo "✅ Authentication working"
echo ""
echo "🔑 Your API Key: $API_KEY"
echo "🌐 API URL: http://localhost:3000"
echo ""
echo "📋 Example usage:"
echo "curl -X POST http://localhost:3000/api/v1/analyze \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -H 'X-API-Key: $API_KEY' \\"
echo "  -d '{\"queries\":[{\"sql\":\"SELECT * FROM users\",\"duration_ms\":100}]}'"
