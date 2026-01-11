# Frontend Implementation Summary

## Overview

This implementation adds a complete web-based frontend to the AI Inference Platform using **Open WebUI**, an open-source, feature-rich LLM interface with built-in authentication.

## What Was Added

### 1. Frontend Application (`frontend/`)

- **Dockerfile**: Containerizes Open WebUI with Azure-specific configuration
- **README.md**: Frontend-specific documentation
- **.dockerignore**: Optimizes Docker build

### 2. Infrastructure as Code (`terraform/container_app.tf`)

Complete Terraform configuration for deploying the frontend:

- **Azure Container Registry**: Stores the Docker image
- **Container App Environment**: Provides the runtime environment
- **Container App**: Runs the Open WebUI frontend with:
  - Auto-scaling (0-3 replicas)
  - HTTPS ingress (public)
  - Secret management for API keys
  - Environment variables for configuration

### 3. Deployment Scripts

- **`deploy-frontend.sh`**: Builds and pushes the Docker image to ACR
- **`setup-frontend-auth.sh`**: Secures the frontend after initial setup

### 4. Documentation (`docs/`)

- **`frontend-deployment.md`**: Complete deployment guide
- **`frontend-usage.md`**: User guide for the web interface

### 5. Updated Files

- **`README.md`**: Added frontend information and quick start guide
- **`terraform/outputs.tf`**: Added outputs for frontend URL and registry info

## Architecture

```
┌─────────────────┐
│   User Browser  │
└────────┬────────┘
         │ HTTPS
         ▼
┌─────────────────────────────┐
│   Azure Container App       │
│   (Open WebUI Frontend)     │
│   - Authentication          │
│   - Model Selection UI      │
│   - Chat Interface          │
└────────┬────────────────────┘
         │ HTTPS + API Key
         ▼
┌─────────────────────────────┐
│   Azure Functions           │
│   (Backend API)             │
│   - Chat Completions        │
│   - Model Routing           │
│   - Caching                 │
└─────────────────────────────┘
```

## Key Features

### 🔐 Built-in Authentication

- Username/password authentication on URL load
- First user becomes admin
- Signup can be disabled after admin creation
- Role-based access control

### 🎨 Rich UI Features

- **Model Selection**: Dropdown to choose from available models
- **Parameter Controls**: Temperature, top_p, max_tokens, etc.
- **System Prompts**: Customize AI behavior
- **Chat History**: Save and manage conversations
- **Streaming**: Real-time response streaming
- **Markdown Support**: Formatted messages with code highlighting

### 🚀 Azure Integration

- **Container Apps**: Serverless container hosting
- **Auto-scaling**: 0-3 replicas based on demand
- **HTTPS**: Automatic TLS certificates
- **Secret Management**: API keys stored securely
- **Cost Optimization**: Scales to zero when idle

## Deployment Flow

1. **Infrastructure Deployment** (`terraform apply`)
   - Creates Container Registry
   - Creates Container App Environment
   - Creates Container App with placeholder image
   - Sets up secrets and environment variables

2. **Frontend Build** (`./deploy-frontend.sh`)
   - Builds Docker image from `frontend/Dockerfile`
   - Tags and pushes to Azure Container Registry
   - Container App automatically pulls new image

3. **Initial Setup** (Manual)
   - User visits frontend URL
   - Creates admin account (first signup)
   - Runs `./setup-frontend-auth.sh` to disable public signup

4. **Ready to Use**
   - Users can authenticate and access the platform
   - Select models, adjust settings, and chat with AI

## Configuration

### Environment Variables (Terraform)

| Variable | Purpose | Default |
|----------|---------|---------|
| `OPENAI_API_BASE_URL` | Backend API endpoint | Azure Functions URL |
| `OPENAI_API_KEY` | API authentication | Generated random key |
| `WEBUI_AUTH` | Enable authentication | `true` |
| `ENABLE_SIGNUP` | Allow new signups | `true` (initially) |
| `WEBUI_NAME` | Application name | "AI Inference Platform" |
| `DEFAULT_USER_ROLE` | Default user role | `user` |
| `PORT` | Container port | `8080` |

### Resource Configuration

- **CPU**: 0.5 cores per instance
- **Memory**: 1Gi per instance
- **Replicas**: 0 minimum, 3 maximum
- **Registry SKU**: Basic
- **Container App**: Consumption-based pricing

## Security

### Authentication Flow

1. User accesses frontend URL
2. Redirected to login page if not authenticated
3. Enters username/password
4. Open WebUI validates credentials
5. Session token stored in browser
6. Subsequent requests include session token

### API Security

- Backend API key stored as Container App secret
- Never exposed in client-side code
- HTTPS enforced for all connections
- CORS configured on backend

### Network Security

- Public ingress (can be changed to private)
- HTTPS only (HTTP redirects to HTTPS)
- Azure Container App firewall available

## Cost Estimates

### Frontend Costs (Monthly)

| State | Cost |
|-------|------|
| Idle (0 replicas) | $0-2 |
| Light usage (avg 0.5 replicas) | $5-10 |
| Active usage (avg 1-2 replicas) | $15-30 |

### Container Registry Costs

| Tier | Storage | Cost |
|------|---------|------|
| Basic | Up to 10 GB | ~$5/month |

**Total Frontend Infrastructure**: ~$5-35/month depending on usage

## Usage Metrics

### Expected Performance

- **Cold start**: 5-10 seconds (when scaled to zero)
- **Warm response**: < 100ms for UI interactions
- **Backend latency**: Depends on model and backend
- **Concurrent users**: Scales up to 3 replicas (30+ concurrent users)

### Monitoring

View Container App metrics in Azure Portal:
- Request count
- Response times
- Active replicas
- CPU/Memory usage

Check logs:
```bash
az containerapp logs show \
  --name ai-inference-platform-frontend \
  --resource-group <resource-group> \
  --tail 100
```

## Maintenance

### Updating Open WebUI

To update to latest version:

1. Run `./deploy-frontend.sh`
2. Image is rebuilt from latest Open WebUI release
3. Container App automatically updates

### Backup and Recovery

- **Configuration**: Stored in Terraform state
- **User data**: Stored in container filesystem (ephemeral)
- **For persistent storage**: Add Azure Files volume mount

### Scaling

Adjust in `terraform/container_app.tf`:

```hcl
min_replicas = 1  # Always keep 1 instance running
max_replicas = 5  # Allow up to 5 instances
```

## Troubleshooting

### Common Issues

1. **Container App not starting**
   - Check logs with `az containerapp logs show`
   - Verify image was pushed successfully
   - Check environment variables

2. **Cannot connect to backend**
   - Verify `OPENAI_API_BASE_URL` is correct
   - Check backend Functions are running
   - Verify API key is correct

3. **Authentication not working**
   - Ensure `WEBUI_AUTH=true`
   - Check browser cookies are enabled
   - Clear browser cache and retry

## Future Enhancements

Possible improvements:

- [ ] Add Azure Files for persistent user data
- [ ] Configure custom domain name
- [ ] Add Azure AD/OAuth authentication
- [ ] Restrict to private VNet
- [ ] Add monitoring dashboard
- [ ] Set up automated backups
- [ ] Configure CDN for static assets

## References

- **Open WebUI**: https://github.com/open-webui/open-webui
- **Documentation**: https://docs.openwebui.com
- **Azure Container Apps**: https://learn.microsoft.com/azure/container-apps/
- **Terraform azurerm provider**: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
