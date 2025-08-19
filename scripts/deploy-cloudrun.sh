#!/bin/bash

# Google Cloud Run Deployment Script for Query Optimizer API
# This script deploys the API to Google Cloud Run with all necessary setup

set -e

echo "☁️  Deploying Query Optimizer API to Google Cloud Run"
echo "===================================================="

# Configuration
PROJECT_ID=""
REGION="us-central1"
SERVICE_NAME="query-optimizer-api"
DATABASE_INSTANCE_NAME="query-optimizer-db"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud SDK is not installed."
    echo "   Install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Get project ID if not set
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [ -z "$PROJECT_ID" ]; then
        echo "❌ No Google Cloud project set."
        echo "   Run: gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
fi

echo "📋 Using project: $PROJECT_ID"
echo "📍 Using region: $REGION"

# Enable required APIs
echo "🔧 Enabling required Google Cloud APIs..."
gcloud services enable cloudbuild.googleapis.com \
                      run.googleapis.com \
                      sql-component.googleapis.com \
                      sqladmin.googleapis.com \
                      secretmanager.googleapis.com

# Create master key secret
echo "🔑 Creating Rails master key secret..."
if [ -f config/master.key ]; then
    gcloud secrets create rails-master-key --data-file=config/master.key --quiet || \
    gcloud secrets versions add rails-master-key --data-file=config/master.key --quiet
    echo "✅ Master key secret created/updated"
else
    echo "⚠️  config/master.key not found. Generating one..."
    openssl rand -hex 32 > config/master.key
    gcloud secrets create rails-master-key --data-file=config/master.key --quiet
    echo "✅ Master key generated and stored in Secret Manager"
fi

# Create Cloud SQL instance
echo "🗄️  Setting up Cloud SQL PostgreSQL instance..."
if ! gcloud sql instances describe $DATABASE_INSTANCE_NAME --quiet 2>/dev/null; then
    echo "📊 Creating Cloud SQL instance (this may take a few minutes)..."
    gcloud sql instances create $DATABASE_INSTANCE_NAME \
        --database-version=POSTGRES_15 \
        --tier=db-f1-micro \
        --region=$REGION \
        --storage-type=SSD \
        --storage-size=10GB \
        --storage-auto-increase \
        --backup-start-time=03:00 \
        --maintenance-window-day=SUN \
        --maintenance-window-hour=04 \
        --deletion-protection
    
    echo "✅ Cloud SQL instance created"
else
    echo "✅ Cloud SQL instance already exists"
fi

# Create database
echo "📊 Creating application database..."
gcloud sql databases create query_optimizer_production \
    --instance=$DATABASE_INSTANCE_NAME --quiet || echo "Database may already exist"

# Create database user
echo "👤 Creating database user..."
DB_PASSWORD=$(openssl rand -base64 32)
gcloud sql users create rails \
    --instance=$DATABASE_INSTANCE_NAME \
    --password=$DB_PASSWORD --quiet || echo "User may already exist"

# Store database password in Secret Manager
echo "🔐 Storing database password in Secret Manager..."
echo -n "$DB_PASSWORD" | gcloud secrets create database-password --data-file=- --quiet || \
echo -n "$DB_PASSWORD" | gcloud secrets versions add database-password --data-file=- --quiet

# Build and deploy using Cloud Build
echo "🏗️  Building and deploying with Cloud Build..."
gcloud builds submit --config cloudbuild.yaml \
    --substitutions=_DATABASE_INSTANCE=$PROJECT_ID:$REGION:$DATABASE_INSTANCE_NAME

# Get the service URL
echo "🔍 Getting service URL..."
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.url)")

# Wait for deployment to be ready
echo "⏳ Waiting for service to be ready..."
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -f "$SERVICE_URL/api/v1/health" > /dev/null 2>&1; then
        echo "✅ Service is ready!"
        break
    else
        echo "⏳ Attempt $attempt/$max_attempts - waiting for service..."
        sleep 10
        ((attempt++))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    echo "❌ Service failed to become ready"
    echo "📋 Checking logs..."
    gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=50
    exit 1
fi

# Create initial API key
echo "🔑 Creating initial API key..."
API_KEY=$(gcloud run services proxy $SERVICE_NAME --region=$REGION --port=8080 &
PROXY_PID=$!
sleep 5

curl -s -X POST http://localhost:8080/api/v1/api_keys \
    -H 'Content-Type: application/json' \
    -d '{"app_name":"Cloud Run Deployment"}' | \
    grep -o '"api_key":"[^"]*"' | cut -d'"' -f4

kill $PROXY_PID 2>/dev/null || true)

echo ""
echo "🎉 Deployment Complete!"
echo "======================"
echo "🌐 Service URL: $SERVICE_URL"
echo "🔑 API Key: $API_KEY"
echo "📊 Database: $PROJECT_ID:$REGION:$DATABASE_INSTANCE_NAME"
echo ""
echo "📋 Quick Test:"
echo "curl -X POST $SERVICE_URL/api/v1/analyze \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -H 'X-API-Key: $API_KEY' \\"
echo "  -d '{\"queries\":[{\"sql\":\"SELECT 1\",\"duration_ms\":10}]}'"
echo ""
echo "📊 Monitor: https://console.cloud.google.com/run/detail/$REGION/$SERVICE_NAME"
echo "💰 Billing: https://console.cloud.google.com/billing"
echo ""
echo "🔧 Useful commands:"
echo "gcloud run services logs read $SERVICE_NAME --region=$REGION"
echo "gcloud run services describe $SERVICE_NAME --region=$REGION"
