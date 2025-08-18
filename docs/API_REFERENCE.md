# API Reference

Complete reference for the Rails Database Query Optimizer API.

## Base URL

```
http://localhost:3000/api/v1
```

## Authentication

All endpoints (except API key creation) require authentication using the `X-API-Key` header:

```
X-API-Key: your_api_key_here
```

## Content Type

All requests should use JSON:

```
Content-Type: application/json
```

## Response Format

All responses follow this structure:

### Success Response
```json
{
  "success": true,
  "data": { ... },
  "message": "Optional success message"
}
```

### Error Response
```json
{
  "success": false,
  "error": "Error message",
  "errors": ["Detailed error 1", "Detailed error 2"]
}
```

## Endpoints

### API Key Management

#### Create API Key
`POST /api/keys`

Create a new API key for your application.

**Request Body:**
```json
{
  "app_name": "string (required, 3-100 characters)"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "app_name": "My Rails App",
    "api_key": "abc123def456...",
    "created_at": "2024-01-15T10:30:00Z"
  },
  "message": "API key created successfully"
}
```

**Error Responses:**
- `400` - Invalid app name or app name already exists
- `500` - Internal server error

#### Get API Key Info
`GET /api_keys/current`

Get information about the current API key.

**Headers Required:**
- `X-API-Key`

**Response:**
```json
{
  "success": true,
  "data": {
    "app_name": "My Rails App",
    "created_at": "2024-01-15T10:30:00Z",
    "last_used": "2024-01-15T15:45:00Z",
    "total_queries": 1250
  }
}
```

#### Regenerate API Key
`POST /api_keys/regenerate`

Generate a new API key (invalidates the current one).

**Headers Required:**
- `X-API-Key`

**Response:**
```json
{
  "success": true,
  "data": {
    "app_name": "My Rails App",
    "api_key": "new_abc123def456...",
    "regenerated_at": "2024-01-15T16:00:00Z"
  },
  "message": "API key regenerated successfully"
}
```

#### Delete API Key
`DELETE /api_keys/current`

Delete the current API key and all associated data.

**Headers Required:**
- `X-API-Key`

**Response:**
```json
{
  "success": true,
  "data": {
    "app_name": "My Rails App",
    "deleted_at": "2024-01-15T16:30:00Z"
  },
  "message": "API key deleted successfully"
}
```

### Query Analysis

#### Analyze Queries
`POST /analyze`

Analyze queries for optimization opportunities.

**Headers Required:**
- `X-API-Key`
- `Content-Type: application/json`

**Request Body:**
```json
{
  "queries": [
    {
      "sql": "string (required, 10-10000 characters)",
      "duration_ms": "number (optional, >= 0)"
    }
  ]
}
```

**Query Validation Rules:**
- Maximum 100 queries per request
- SQL must be valid SELECT, INSERT, UPDATE, or DELETE
- No dangerous operations (DROP, TRUNCATE, etc.)
- Duration must be between 0 and 3,600,000 ms (1 hour)

**Response:**
```json
{
  "success": true,
  "data": {
    "n_plus_one": {
      "detected": true,
      "patterns": [
        {
          "table": "posts",
          "column": "user_id",
          "query_count": 5,
          "suggestion": "Use includes(:user) to preload associations",
          "example_sql": "Post.includes(:user).where(...)",
          "severity": "high"
        }
      ]
    },
    "slow_queries": [
      {
        "sql": "SELECT * FROM users WHERE email LIKE '%@gmail.com'",
        "duration_ms": 2000,
        "severity": "very_slow",
        "suggestions": [
          "Add index on email column",
          "Avoid leading wildcards in LIKE queries",
          "Consider full-text search for email patterns"
        ],
        "estimated_improvement": "80% faster with proper indexing"
      }
    ],
    "missing_indexes": [
      {
        "table": "users",
        "columns": ["email"],
        "sql": "CREATE INDEX idx_users_email ON users (email);",
        "priority": "high",
        "estimated_impact": "Reduce query time from 2000ms to 50ms",
        "usage_frequency": "high"
      }
    ],
    "summary": {
      "total_queries": 10,
      "issues_found": 3,
      "optimization_score": 75,
      "performance_impact": "medium"
    }
  }
}
```

**Error Responses:**
- `400` - Validation errors (invalid SQL, too many queries, etc.)
- `401` - Invalid or missing API key
- `429` - Rate limit exceeded
- `500` - Internal server error

#### CI/CD Analysis
`POST /analyze_ci`

Analyze queries with pass/fail scoring for CI/CD integration.

**Headers Required:**
- `X-API-Key`
- `Content-Type: application/json`

**Request Body:**
```json
{
  "queries": [
    {
      "sql": "string (required)",
      "duration_ms": "number (optional)"
    }
  ],
  "threshold_score": "number (optional, 0-100, default: 70)"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "score": 85,
    "passed": true,
    "threshold": 80,
    "issues": {
      "n_plus_one": 1,
      "slow_queries": 2,
      "missing_indexes": 1,
      "total": 4
    },
    "recommendations": [
      "Add eager loading for user associations",
      "Create index on posts.user_id",
      "Optimize WHERE clause in user search query"
    ],
    "details": {
      "performance_score": 80,
      "maintainability_score": 90,
      "scalability_score": 85
    }
  }
}
```

**Scoring Algorithm:**
- Base score: 100
- N+1 queries: -10 points each
- Slow queries: -5 to -20 points based on severity
- Missing indexes: -5 to -15 points based on impact
- Minimum score: 0

### Health Check

#### Health Status
`GET /health`

Check the health status of the API and its dependencies.

**No authentication required**

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0.0",
  "services": {
    "database": "ok",
    "sql_parser": "ok",
    "analysis_services": "ok"
  },
  "uptime": "5 days, 12 hours",
  "memory_usage": "245MB"
}
```

**Status Values:**
- `ok` - All services healthy
- `degraded` - Some services have issues
- `down` - Critical services unavailable

**Service Status:**
- `ok` - Service is healthy
- `error` - Service has issues

## Rate Limiting

- **1000 requests per hour** per API key
- Rate limit resets every hour
- Rate limit headers included in all responses:

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642248000
```

When rate limit is exceeded:
```json
{
  "success": false,
  "error": "Rate limit exceeded. Maximum 1000 requests per hour.",
  "retry_after": 3600
}
```

## Error Codes

| HTTP Status | Error Type | Description |
|-------------|------------|-------------|
| 400 | Bad Request | Invalid request data or validation errors |
| 401 | Unauthorized | Missing or invalid API key |
| 404 | Not Found | Endpoint not found |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server error |
| 503 | Service Unavailable | Service temporarily unavailable |

## Query Analysis Details

### N+1 Detection Algorithm

The API detects N+1 queries by:
1. Grouping similar queries by normalized SQL signature
2. Identifying time clusters of repeated queries
3. Analyzing foreign key patterns
4. Suggesting eager loading solutions

### Slow Query Analysis

Queries are classified by duration:
- **Fast**: < 100ms
- **Moderate**: 100-500ms  
- **Slow**: 500-1000ms
- **Very Slow**: 1000-5000ms
- **Critical**: > 5000ms

### Index Recommendations

The API analyzes:
- WHERE clause columns
- JOIN conditions
- ORDER BY columns
- Composite index opportunities
- Existing index usage

## Best Practices

### Request Optimization
- Batch multiple queries in a single request
- Include duration_ms when available for better analysis
- Use meaningful SQL with actual table/column names

### Error Handling
- Always check the `success` field
- Handle rate limiting with exponential backoff
- Log detailed errors for debugging

### Security
- Store API keys securely (environment variables)
- Use HTTPS in production
- Rotate API keys regularly

### CI/CD Integration
- Set appropriate threshold scores for your application
- Monitor trends over time
- Fail builds on critical performance regressions
