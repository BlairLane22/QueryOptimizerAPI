# Google Cloud Run Deployment Guide

Complete guide for deploying the Query Optimizer API to Google Cloud Run with automatic scaling and managed database.

## 🚀 Quick Start

### One-Command Deployment

```bash
# 1. Setup Google Cloud Platform
./scripts/setup-gcp.sh

# 2. Deploy to Cloud Run
./scripts/deploy-cloudrun.sh

# 3. Test the deployment
./scripts/test-cloudrun.sh
```

## 📋 Prerequisites

### 1. Install Google Cloud SDK

```bash
# macOS
brew install google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash

# Windows
# Download from: https://cloud.google.com/sdk/docs/install
```

### 2. Verify Installation

```bash
gcloud --version
gcloud auth login
gcloud projects list
```

## 🛠️ Manual Setup

### 1. Create Google Cloud Project

```bash
# Create new project
gcloud projects create your-project-id --name="Query Optimizer API"

# Set as default project
gcloud config set project your-project-id

# Enable billing (required for Cloud Run)
gcloud billing projects link your-project-id --billing-account=YOUR_BILLING_ACCOUNT
```

### 2. Enable Required APIs

```bash
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    sql-component.googleapis.com \
    sqladmin.googleapis.com \
    secretmanager.googleapis.com
```

### 3. Setup Database

```bash
# Create Cloud SQL PostgreSQL instance
gcloud sql instances create query-optimizer-db \
    --database-version=POSTGRES_15 \
    --tier=db-f1-micro \
    --region=us-central1 \
    --storage-type=SSD \
    --storage-size=10GB

# Create database
gcloud sql databases create query_optimizer_production \
    --instance=query-optimizer-db

# Create user
gcloud sql users create rails \
    --instance=query-optimizer-db \
    --password=YOUR_SECURE_PASSWORD
```

### 4. Setup Secrets

```bash
# Store Rails master key
gcloud secrets create rails-master-key --data-file=config/master.key

# Store database password
echo -n "YOUR_DB_PASSWORD" | gcloud secrets create database-password --data-file=-
```

### 5. Build and Deploy

```bash
# Build with Cloud Build
gcloud builds submit --config cloudbuild.yaml

# Deploy to Cloud Run
gcloud run deploy query-optimizer-api \
    --image gcr.io/YOUR_PROJECT_ID/query-optimizer-api:latest \
    --region us-central1 \
    --platform managed \
    --allow-unauthenticated \
    --memory 512Mi \
    --cpu 1 \
    --max-instances 10 \
    --set-cloudsql-instances YOUR_PROJECT_ID:us-central1:query-optimizer-db
```

## 🔧 Configuration

### Environment Variables

The deployment automatically sets these environment variables:

```bash
RAILS_ENV=production
PORT=8080
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true
DATABASE_URL=postgresql://rails:PASSWORD@/query_optimizer_production?host=/cloudsql/PROJECT_ID:us-central1:query-optimizer-db
```

### Resource Limits

```yaml
# Default configuration
Memory: 512Mi
CPU: 1 vCPU
Max Instances: 10
Timeout: 300 seconds
Concurrency: 80 requests per instance
```

### Scaling Configuration

```yaml
# Automatic scaling
Min Instances: 0 (scales to zero when no traffic)
Max Instances: 10
Target CPU: 60%
Target Concurrency: 80 requests per instance
```

## 📊 Monitoring and Logging

### View Logs

```bash
# Real-time logs
gcloud run services logs read query-optimizer-api --region=us-central1 --follow

# Recent logs
gcloud run services logs read query-optimizer-api --region=us-central1 --limit=100

# Filter logs
gcloud run services logs read query-optimizer-api --region=us-central1 --filter="severity>=ERROR"
```

### Monitor Performance

```bash
# Service details
gcloud run services describe query-optimizer-api --region=us-central1

# Traffic allocation
gcloud run services describe query-optimizer-api --region=us-central1 --format="value(status.traffic[0].percent)"

# Latest revision
gcloud run revisions list --service=query-optimizer-api --region=us-central1
```

### Cloud Console Monitoring

- **Service Overview**: https://console.cloud.google.com/run
- **Logs**: https://console.cloud.google.com/logs
- **Metrics**: https://console.cloud.google.com/monitoring
- **Billing**: https://console.cloud.google.com/billing

## 🔒 Security

### IAM and Service Accounts

```bash
# Create service account
gcloud iam service-accounts create query-optimizer \
    --display-name="Query Optimizer API"

# Grant Cloud SQL access
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:query-optimizer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudsql.client"

# Grant Secret Manager access
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:query-optimizer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
```

### Network Security

```bash
# Restrict ingress (optional)
gcloud run services update query-optimizer-api \
    --region=us-central1 \
    --ingress=internal-and-cloud-load-balancing

# Add VPC connector (optional)
gcloud compute networks vpc-access connectors create default \
    --region=us-central1 \
    --subnet=default \
    --subnet-project=YOUR_PROJECT_ID
```

## 💰 Cost Optimization

### Free Tier Usage

```bash
# Monitor free tier usage
gcloud billing budgets list --billing-account=YOUR_BILLING_ACCOUNT

# Set up billing alerts
gcloud billing budgets create \
    --billing-account=YOUR_BILLING_ACCOUNT \
    --display-name="Query Optimizer Budget" \
    --budget-amount=10USD \
    --threshold-rule=percent=50,basis=CURRENT_SPEND \
    --threshold-rule=percent=90,basis=CURRENT_SPEND
```

### Cost Breakdown

```
Free Tier (per month):
- 2 million requests
- 400,000 GB-seconds memory
- 200,000 vCPU-seconds
- 1 GB network egress

Paid Tier (after free tier):
- $0.40 per million requests
- $0.0000025 per GB-second
- $0.0000100 per vCPU-second
- $0.12 per GB network egress
```

### Optimization Tips

```bash
# Reduce cold starts
gcloud run services update query-optimizer-api \
    --region=us-central1 \
    --min-instances=1

# Optimize memory usage
gcloud run services update query-optimizer-api \
    --region=us-central1 \
    --memory=256Mi

# Set CPU allocation
gcloud run services update query-optimizer-api \
    --region=us-central1 \
    --cpu=0.5
```

## 🔄 CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy to Cloud Run

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - id: 'auth'
      uses: 'google-github-actions/auth@v1'
      with:
        credentials_json: '${{ secrets.GCP_SA_KEY }}'
    
    - name: 'Set up Cloud SDK'
      uses: 'google-github-actions/setup-gcloud@v1'
    
    - name: 'Build and Deploy'
      run: |
        gcloud builds submit --config cloudbuild.yaml
```

### Automated Testing

```bash
# Add to cloudbuild.yaml
steps:
  # ... build steps ...
  
  # Run tests
  - name: 'gcr.io/$PROJECT_ID/query-optimizer-api:$COMMIT_SHA'
    entrypoint: '/bin/bash'
    args: ['-c', 'bundle exec rspec']
    
  # Deploy only if tests pass
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args: ['run', 'deploy', ...]
```

## 🐛 Troubleshooting

### Common Issues

**Service not responding:**
```bash
# Check service status
gcloud run services describe query-optimizer-api --region=us-central1

# Check logs for errors
gcloud run services logs read query-optimizer-api --region=us-central1 --limit=50
```

**Database connection failed:**
```bash
# Check Cloud SQL instance
gcloud sql instances describe query-optimizer-db

# Test connection
gcloud sql connect query-optimizer-db --user=rails
```

**Build failures:**
```bash
# Check build logs
gcloud builds list --limit=5
gcloud builds log BUILD_ID
```

**Memory or CPU limits:**
```bash
# Increase resources
gcloud run services update query-optimizer-api \
    --region=us-central1 \
    --memory=1Gi \
    --cpu=2
```

### Debug Mode

```bash
# Enable debug logging
gcloud run services update query-optimizer-api \
    --region=us-central1 \
    --set-env-vars="RAILS_LOG_LEVEL=debug"

# Connect to Cloud SQL for debugging
gcloud sql connect query-optimizer-db --user=rails

# Check environment variables
gcloud run services describe query-optimizer-api \
    --region=us-central1 \
    --format="value(spec.template.spec.containers[0].env[].name,spec.template.spec.containers[0].env[].value)"
```

## 📞 Support

- **Documentation**: https://cloud.google.com/run/docs
- **Pricing**: https://cloud.google.com/run/pricing
- **Support**: https://cloud.google.com/support
- **Community**: https://stackoverflow.com/questions/tagged/google-cloud-run

---

**Ready to deploy?** Run `./scripts/setup-gcp.sh` followed by `./scripts/deploy-cloudrun.sh` and you'll have a production-ready Query Optimizer API running on Google Cloud Run! ☁️
