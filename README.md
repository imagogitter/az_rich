# AI Inference Arbitrage Platform

GPU-based AI inference reselling platform with 200-300% margins using Azure spot instances.

## Quick Start

**🚀 [Frontend Quick Start Guide](QUICKSTART-FRONTEND.md)** - Get up and running in 4 steps!

### Option 1: Automated Deployment (GitHub Actions)

1. Configure repository secrets:
   - `AZURE_CREDENTIALS` - Azure service principal credentials
   
2. Push to `main` branch or manually trigger the "Frontend Deployment" workflow

3. Download artifacts for connection details and LLM API configuration

### Option 2: Local One-Command Deployment

```bash
# Complete deployment (infrastructure + frontend + connection details)
./setup-frontend-complete.sh
```

### Option 3: Manual Step-by-Step

```bash
# Step 1: Deploy infrastructure
cd terraform && terraform init && terraform apply

# Step 2: Deploy frontend
cd .. && ./deploy-frontend.sh

# Step 3: Get frontend URL and create admin account
cd terraform && terraform output frontend_url
# Visit the URL and create your admin account

# Step 4: Secure the frontend (disable public signup)
cd .. && ./setup-frontend-auth.sh
```

For detailed instructions, see the [Frontend Deployment Guide](docs/frontend-deployment.md).

## Frontend Web UI

The platform includes **Open WebUI**, a feature-rich web interface for interacting with the AI models:

- 🔐 **Built-in Authentication**: Username/password prompt on first load
- 🎨 **Modern UI**: Fast, responsive React-based interface
- 🤖 **Model Selection**: Choose from Llama-3-70B, Mixtral 8x7B, Phi-3-mini
- ⚙️ **Full Settings**: Temperature, top_p, max_tokens, and more
- 💬 **Chat Modes**: Single chat, multi-turn conversations, system prompts
- 📝 **History**: Save and manage conversation history

### Accessing the Frontend

After deployment, get the frontend URL:
```bash
cd terraform && terraform output frontend_url
```

Navigate to the URL and create an admin account on first visit.

## Architecture

- API Layer: Azure API Management (consumption tier)
- Compute: VM Scale Sets with Spot priority (80% discount)
- Models: Llama-3-70B, Mixtral 8x7B, Phi-3-mini
- Caching: Azure Cosmos DB (serverless)
- Orchestration: Azure Functions (consumption)
- Frontend: Open WebUI on Azure Container Apps
- Secrets: Azure Key Vault

## Features

- ✅ Web UI with authentication and full model control
- ✅ Health check endpoints with liveness/readiness probes
- ✅ Azure Key Vault secrets management
- ✅ Terraform & Bicep IaC
- ✅ GitHub Actions CI/CD
- ✅ Auto-scaling 0-20 GPU instances
- ✅ 40% cache hit rate
- ✅ <30s spot preemption failover

## Costs

| State | Monthly Cost |
|-------|--------------|
| Idle | ~$5 |
| Active (10 instances avg) | ~$1,100 |
| Revenue potential | ~$4,000+ |

## Documentation

- [Frontend Deployment Guide](docs/frontend-deployment.md)
- [Frontend Usage Guide](docs/frontend-usage.md)
- [GitHub Actions Frontend Deployment](docs/github-actions-frontend-deployment.md)
- [Operations & Production Guide](docs/operations-guide.md)
- [Load Testing Guide](scripts/README-load-testing.md)