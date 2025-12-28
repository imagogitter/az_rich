# API Usage Guide

## Authentication

```bash
curl -H "Authorization: Bearer YOUR_KEY" \
  https://your-apim.azure-api.net/v1/chat/completions \
  -d '{"model": "mixtral-8x7b", "messages": [...]}'
```

## Endpoints

- POST `/v1/chat/completions` - Generate completions
- GET `/health/live` - Liveness check
- GET `/health/ready` - Readiness check
