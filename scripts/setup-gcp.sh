#!/bin/bash

# Google Cloud Platform Setup Script for Query Optimizer API
# This script sets up a new GCP project and prepares it for deployment

set -e

echo "🌩️  Google Cloud Platform Setup"
echo "==============================="

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud SDK is not installed."
    echo ""
    echo "📥 Install Google Cloud SDK:"
    echo "   macOS: brew install google-cloud-sdk"
    echo "   Linux: curl https://sdk.cloud.google.com | bash"
    echo "   Windows: https://cloud.google.com/sdk/docs/install"
    echo ""
    exit 1
fi

echo "✅ Google Cloud SDK is installed"

# Login to Google Cloud
echo "🔐 Logging into Google Cloud..."
gcloud auth login

# List available projects
echo "📋 Available projects:"
gcloud projects list --format="table(projectId,name,projectNumber)"

echo ""
read -p "Enter your project ID (or press Enter to create a new one): " PROJECT_ID

if [ -z "$PROJECT_ID" ]; then
    # Create new project
    echo "🆕 Creating new project..."
    read -p "Enter project name: " PROJECT_NAME
    PROJECT_ID=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')-$(date +%s)
    
    gcloud projects create $PROJECT_ID --name="$PROJECT_NAME"
    echo "✅ Project created: $PROJECT_ID"
fi

# Set the project
echo "🎯 Setting project: $PROJECT_ID"
gcloud config set project $PROJECT_ID

# Enable billing (required for Cloud Run)
echo "💳 Checking billing..."
BILLING_ACCOUNT=$(gcloud billing accounts list --format="value(name)" --filter="open:true" --limit=1)

if [ -z "$BILLING_ACCOUNT" ]; then
    echo "❌ No billing account found."
    echo "   Please set up billing at: https://console.cloud.google.com/billing"
    echo "   Then run this script again."
    exit 1
fi

# Link billing account to project
gcloud billing projects link $PROJECT_ID --billing-account=$BILLING_ACCOUNT
echo "✅ Billing account linked"

# Enable required APIs
echo "🔧 Enabling required APIs..."
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    sql-component.googleapis.com \
    sqladmin.googleapis.com \
    secretmanager.googleapis.com \
    container.googleapis.com

echo "✅ APIs enabled"

# Set default region
echo "🌍 Setting default region..."
gcloud config set run/region us-central1
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a

# Create service account for Cloud Run
echo "👤 Creating service account..."
SERVICE_ACCOUNT_EMAIL="query-optimizer@$PROJECT_ID.iam.gserviceaccount.com"

gcloud iam service-accounts create query-optimizer \
    --display-name="Query Optimizer API" \
    --description="Service account for Query Optimizer API" || echo "Service account may already exist"

# Grant necessary permissions
echo "🔐 Granting permissions..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/cloudsql.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/secretmanager.secretAccessor"

# Create application credentials
echo "🔑 Creating application credentials..."
mkdir -p ~/.config/gcloud
gcloud iam service-accounts keys create ~/.config/gcloud/query-optimizer-key.json \
    --iam-account=$SERVICE_ACCOUNT_EMAIL

export GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcloud/query-optimizer-key.json

echo ""
echo "🎉 Google Cloud Platform Setup Complete!"
echo "========================================"
echo "📋 Project ID: $PROJECT_ID"
echo "🌍 Region: us-central1"
echo "👤 Service Account: $SERVICE_ACCOUNT_EMAIL"
echo "🔑 Credentials: ~/.config/gcloud/query-optimizer-key.json"
echo ""
echo "🚀 Next Steps:"
echo "1. Run: ./scripts/deploy-cloudrun.sh"
echo "2. Monitor: https://console.cloud.google.com/run"
echo "3. Billing: https://console.cloud.google.com/billing"
echo ""
echo "💡 Useful commands:"
echo "gcloud config list"
echo "gcloud projects describe $PROJECT_ID"
echo "gcloud billing projects describe $PROJECT_ID"
