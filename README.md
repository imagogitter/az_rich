# AI Inference Arbitrage Platform

GPU-based AI inference reselling platform with 200-300% margins using Azure spot instances.

## Quick Start

```bash
# Option 1: Full deployment with frontend
./deploy.sh              # Deploy infrastructure
./deploy-frontend.sh     # Deploy frontend UI

# Option 2: Terraform
cd terraform && terraform init && terraform apply
./deploy-frontend.sh

# Option 3: Bicep
az deployment sub create --location eastus --template-file bicep/main.bicep
```

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

- Deployment Guide
- API Usage
- Architecture
- Runbook