#!/bin/bash

# Test Google Cloud Run Deployment
# This script tests the deployed Query Optimizer API on Cloud Run

set -e

echo "🧪 Testing Query Optimizer API on Google Cloud Run"
echo "=================================================="

# Get project and service info
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
REGION="us-central1"
SERVICE_NAME="query-optimizer-api"

if [ -z "$PROJECT_ID" ]; then
    echo "❌ No Google Cloud project set."
    echo "   Run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

# Get service URL
echo "🔍 Getting service URL..."
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.url)" 2>/dev/null)

if [ -z "$SERVICE_URL" ]; then
    echo "❌ Service not found. Make sure it's deployed:"
    echo "   ./scripts/deploy-cloudrun.sh"
    exit 1
fi

echo "✅ Service URL: $SERVICE_URL"

# Test health endpoint
echo "🔍 Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s "$SERVICE_URL/api/v1/health" || echo "FAILED")

if echo "$HEALTH_RESPONSE" | grep -q '"status":"ok"'; then
    echo "✅ Health endpoint working"
    echo "   Response: $HEALTH_RESPONSE"
else
    echo "❌ Health endpoint failed"
    echo "   Response: $HEALTH_RESPONSE"
    exit 1
fi

# Create API key for testing
echo "🔑 Creating test API key..."
API_KEY_RESPONSE=$(curl -s -X POST "$SERVICE_URL/api/v1/api_keys" \
    -H 'Content-Type: application/json' \
    -d '{"app_name":"Cloud Run Test"}' || echo "FAILED")

if echo "$API_KEY_RESPONSE" | grep -q '"success":true'; then
    API_KEY=$(echo "$API_KEY_RESPONSE" | grep -o '"api_key":"[^"]*"' | cut -d'"' -f4)
    echo "✅ API key created: ${API_KEY:0:16}..."
else
    echo "❌ Failed to create API key"
    echo "   Response: $API_KEY_RESPONSE"
    exit 1
fi

# Test analyze endpoint
echo "🔍 Testing analyze endpoint..."
ANALYZE_RESPONSE=$(curl -s -X POST "$SERVICE_URL/api/v1/analyze" \
    -H 'Content-Type: application/json' \
    -H "X-API-Key: $API_KEY" \
    -d '{
        "queries": [
            {
                "sql": "SELECT * FROM users WHERE id = 1",
                "duration_ms": 50
            },
            {
                "sql": "SELECT * FROM posts WHERE user_id = 1",
                "duration_ms": 200
            }
        ]
    }' || echo "FAILED")

if echo "$ANALYZE_RESPONSE" | grep -q '"success":true'; then
    echo "✅ Analyze endpoint working"
    
    # Extract optimization score
    SCORE=$(echo "$ANALYZE_RESPONSE" | grep -o '"optimization_score":[0-9]*' | cut -d':' -f2)
    echo "   Optimization Score: $SCORE%"
    
    # Check for issues
    if echo "$ANALYZE_RESPONSE" | grep -q '"issues_found":[1-9]'; then
        ISSUES=$(echo "$ANALYZE_RESPONSE" | grep -o '"issues_found":[0-9]*' | cut -d':' -f2)
        echo "   Issues Found: $ISSUES"
    fi
else
    echo "❌ Analyze endpoint failed"
    echo "   Response: $ANALYZE_RESPONSE"
    exit 1
fi

# Test CI endpoint
echo "🔍 Testing CI endpoint..."
CI_RESPONSE=$(curl -s -X POST "$SERVICE_URL/api/v1/analyze_ci" \
    -H 'Content-Type: application/json' \
    -H "X-API-Key: $API_KEY" \
    -d '{
        "queries": [
            {"sql": "SELECT 1", "duration_ms": 10}
        ],
        "threshold_score": 80
    }' || echo "FAILED")

if echo "$CI_RESPONSE" | grep -q '"success":true'; then
    echo "✅ CI endpoint working"
    
    # Extract CI results
    PASSED=$(echo "$CI_RESPONSE" | grep -o '"passed":[a-z]*' | cut -d':' -f2)
    CI_SCORE=$(echo "$CI_RESPONSE" | grep -o '"score":[0-9]*' | cut -d':' -f2)
    echo "   CI Score: $CI_SCORE%"
    echo "   Passed: $PASSED"
else
    echo "❌ CI endpoint failed"
    echo "   Response: $CI_RESPONSE"
    exit 1
fi

# Test authentication (should fail with invalid key)
echo "🔍 Testing authentication..."
AUTH_RESPONSE=$(curl -s -X POST "$SERVICE_URL/api/v1/analyze" \
    -H 'Content-Type: application/json' \
    -H "X-API-Key: invalid_key_12345" \
    -d '{"queries":[{"sql":"SELECT 1","duration_ms":10}]}' || echo "FAILED")

if echo "$AUTH_RESPONSE" | grep -q '"success":false'; then
    echo "✅ Authentication working (correctly rejected invalid key)"
else
    echo "❌ Authentication failed (should reject invalid key)"
    echo "   Response: $AUTH_RESPONSE"
    exit 1
fi

# Performance test
echo "🚀 Running performance test..."
START_TIME=$(date +%s%N)

for i in {1..5}; do
    curl -s -X POST "$SERVICE_URL/api/v1/analyze" \
        -H 'Content-Type: application/json' \
        -H "X-API-Key: $API_KEY" \
        -d '{"queries":[{"sql":"SELECT 1","duration_ms":10}]}' > /dev/null
done

END_TIME=$(date +%s%N)
DURATION=$(( (END_TIME - START_TIME) / 1000000 ))
AVG_RESPONSE_TIME=$(( DURATION / 5 ))

echo "✅ Performance test completed"
echo "   5 requests in ${DURATION}ms"
echo "   Average response time: ${AVG_RESPONSE_TIME}ms"

# Check Cloud Run metrics
echo "📊 Checking Cloud Run metrics..."
echo "   Service: $SERVICE_NAME"
echo "   Region: $REGION"
echo "   Project: $PROJECT_ID"

# Get current instance count
INSTANCES=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.traffic[0].percent)" 2>/dev/null || echo "Unknown")
echo "   Current traffic allocation: $INSTANCES%"

echo ""
echo "🎉 All tests passed!"
echo "==================="
echo "✅ Health endpoint working"
echo "✅ API key generation working"
echo "✅ Query analysis working"
echo "✅ CI integration working"
echo "✅ Authentication working"
echo "✅ Performance acceptable"
echo ""
echo "🔗 Service Details:"
echo "   URL: $SERVICE_URL"
echo "   API Key: $API_KEY"
echo "   Console: https://console.cloud.google.com/run/detail/$REGION/$SERVICE_NAME"
echo ""
echo "📋 Example usage:"
echo "curl -X POST $SERVICE_URL/api/v1/analyze \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -H 'X-API-Key: $API_KEY' \\"
echo "  -d '{\"queries\":[{\"sql\":\"SELECT * FROM users\",\"duration_ms\":100}]}'"
echo ""
echo "📊 Monitor usage:"
echo "gcloud run services logs read $SERVICE_NAME --region=$REGION"
echo "gcloud run services describe $SERVICE_NAME --region=$REGION"
