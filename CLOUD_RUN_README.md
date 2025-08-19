# ☁️ Google Cloud Run Deployment

Deploy the Query Optimizer API to Google Cloud Run with automatic scaling and 2 million free requests per month!

## 🚀 One-Command Deployment

```bash
# 1. Setup Google Cloud (one-time)
./scripts/setup-gcp.sh

# 2. Deploy to Cloud Run
./scripts/deploy-cloudrun.sh

# 3. Test your deployment
./scripts/test-cloudrun.sh
```

**That's it!** Your API will be live at `https://query-optimizer-api-xxx-uc.a.run.app`

## 💰 Free Tier Benefits

Google Cloud Run free tier includes:
- ✅ **2 million requests/month** (enough for 30,000+ daily user interactions)
- ✅ **400,000 GB-seconds memory** 
- ✅ **200,000 vCPU-seconds**
- ✅ **Automatic scaling** (scales to zero when not used)
- ✅ **Global CDN** and HTTPS included
- ✅ **No server management** required

## 📋 What You Get

After deployment, you'll have:

- 🌐 **Public API endpoint** with HTTPS
- 🗄️ **Managed PostgreSQL database** (Cloud SQL)
- 🔐 **Secure secrets management**
- 📊 **Automatic monitoring and logging**
- 🚀 **Auto-scaling** (0 to 10 instances)
- 💳 **Cost-effective** (free tier covers most usage)

## 🔧 Prerequisites

1. **Google Cloud Account** (free tier available)
2. **Google Cloud SDK** installed
3. **Billing enabled** (required for Cloud Run, but free tier covers most usage)

### Install Google Cloud SDK

```bash
# macOS
brew install google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash

# Windows
# Download from: https://cloud.google.com/sdk/docs/install
```

## 📊 Usage Examples

Once deployed, your API will be available at your Cloud Run URL:

### Get API Key

```bash
# The deployment script automatically creates one, or create manually:
curl -X POST https://your-service-url/api/v1/api_keys \
  -H 'Content-Type: application/json' \
  -d '{"app_name":"My Rails App"}'
```

### Analyze Queries

```bash
curl -X POST https://your-service-url/api/v1/analyze \
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

### CI Integration

```bash
curl -X POST https://your-service-url/api/v1/analyze_ci \
  -H 'Content-Type: application/json' \
  -H 'X-API-Key: your_api_key_here' \
  -d '{
    "queries": [{"sql": "SELECT 1", "duration_ms": 10}],
    "threshold_score": 80
  }'
```

## 🔍 Monitoring

### View Logs

```bash
# Real-time logs
gcloud run services logs read query-optimizer-api --region=us-central1 --follow

# Recent errors
gcloud run services logs read query-optimizer-api --region=us-central1 --filter="severity>=ERROR"
```

### Monitor Usage

- **Service Dashboard**: https://console.cloud.google.com/run
- **Billing Dashboard**: https://console.cloud.google.com/billing
- **Logs**: https://console.cloud.google.com/logs

## 🔧 Configuration

### Environment Variables

The deployment automatically configures:

```bash
RAILS_ENV=production
DATABASE_URL=postgresql://...  # Managed Cloud SQL
RAILS_MASTER_KEY=...          # Stored in Secret Manager
```

### Resource Limits

```yaml
Memory: 512Mi
CPU: 1 vCPU
Max Instances: 10
Timeout: 300 seconds
```

### Custom Configuration

Edit `cloudbuild.yaml` to customize:

```yaml
# Increase memory
--memory=1Gi

# Increase CPU
--cpu=2

# Change region
--region=europe-west1

# Set max instances
--max-instances=20
```

## 💡 Cost Optimization

### Monitor Costs

```bash
# Set up billing alerts
gcloud billing budgets create \
  --billing-account=YOUR_BILLING_ACCOUNT \
  --display-name="Query Optimizer Budget" \
  --budget-amount=10USD
```

### Optimize Usage

1. **Batch requests** - Send multiple queries in one request
2. **Cache results** - Cache analysis results for identical queries
3. **Smart thresholds** - Only analyze requests with 5+ queries
4. **Monitor usage** - Track request patterns and optimize

## 🚀 Scaling

### Automatic Scaling

Cloud Run automatically scales based on:
- **Request volume** - Scales up with more requests
- **CPU usage** - Scales up when CPU is high
- **Memory usage** - Scales up when memory is high
- **Zero scaling** - Scales to zero when no requests

### Manual Scaling

```bash
# Set minimum instances (reduces cold starts)
gcloud run services update query-optimizer-api \
  --region=us-central1 \
  --min-instances=1

# Set maximum instances
gcloud run services update query-optimizer-api \
  --region=us-central1 \
  --max-instances=20
```

## 🔒 Security

### Built-in Security

- ✅ **HTTPS by default** - All traffic encrypted
- ✅ **IAM integration** - Fine-grained access control
- ✅ **Secret management** - Secure credential storage
- ✅ **VPC support** - Network isolation available
- ✅ **Container security** - Runs in secure sandbox

### API Security

- ✅ **API key authentication** - Secure access control
- ✅ **Rate limiting** - Prevents abuse
- ✅ **Input validation** - SQL injection protection
- ✅ **CORS support** - Cross-origin request handling

## 🐛 Troubleshooting

### Common Issues

**Deployment failed:**
```bash
# Check build logs
gcloud builds list --limit=5
gcloud builds log BUILD_ID
```

**Service not responding:**
```bash
# Check service status
gcloud run services describe query-optimizer-api --region=us-central1

# Check logs
gcloud run services logs read query-optimizer-api --region=us-central1 --limit=50
```

**Database connection issues:**
```bash
# Check Cloud SQL instance
gcloud sql instances describe query-optimizer-db

# Test connection
gcloud sql connect query-optimizer-db --user=rails
```

### Get Help

- 📖 **Full Guide**: See `docs/CLOUD_RUN_GUIDE.md`
- 🌐 **Google Cloud Docs**: https://cloud.google.com/run/docs
- 💬 **Community**: https://stackoverflow.com/questions/tagged/google-cloud-run

## 🎯 Next Steps

1. **Deploy**: Run `./scripts/setup-gcp.sh` then `./scripts/deploy-cloudrun.sh`
2. **Test**: Run `./scripts/test-cloudrun.sh` to verify everything works
3. **Integrate**: Use the API URL in your Rails applications
4. **Monitor**: Set up billing alerts and monitor usage
5. **Scale**: Adjust resources as your usage grows

---

**Ready to go serverless?** Your Query Optimizer API will be running on Google Cloud Run in minutes! ☁️🚀
