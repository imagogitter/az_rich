# AI Inference Arbitrage Platform

GPU-based AI inference reselling platform with 200-300% margins using Azure spot instances.

## Quick Start

**🚀 [Full Deployment Workflow Guide](docs/workflow-deployment-guide.md)** - Complete GitHub Actions deployment!

### Option 1: Automated Deployment (GitHub Actions) **[RECOMMENDED]**

1. **Configure repository secrets:**
   - `AZURE_CREDENTIALS` - Azure service principal credentials
   
2. **Trigger the workflow:**
   - Go to [Actions → Full Azure Deployment](https://github.com/imagogitter/az_rich/actions/workflows/full-deployment.yml)
   - Click "Run workflow"
   - Select branch and environment
   - Click "Run workflow" button
   
3. **Download deployment artifacts** for:
   - Complete endpoint details
   - API keys and configuration
   - Usage examples and documentation
   
📖 **See [Workflow Deployment Guide](docs/workflow-deployment-guide.md) for detailed instructions**

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

- **[Complete Deployment Guide](DEPLOYMENT-GUIDE.md)** - Comprehensive deployment reference
- **[Workflow Deployment Guide](docs/workflow-deployment-guide.md)** - GitHub Actions deployment
- [Frontend Deployment Guide](docs/frontend-deployment.md) - Frontend-specific guide
- [Frontend Usage Guide](docs/frontend-usage.md) - Using the web interface
- [OpenAPI Specification](openapi.json) - API reference
- [Production README](PRODUCTION-README.md) - Production deployment details