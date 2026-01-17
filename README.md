# AI Inference Arbitrage Platform

GPU-based AI inference reselling platform with 200-300% margins using Azure spot instances.

## Quick Start

### 🚀 One-Command Setup (Recommended)

```bash
./setup-frontend-complete.sh
```

This automated script handles everything: infrastructure, frontend, setup, and security!

### 📚 Documentation & Commands

- **[Command Reference](FRONTEND-COMMANDS.md)** - All commands for setup, launch, and testing
- **[LLM Connection Guide](docs/LLM-CONNECTION-GUIDE.md)** - Complete API integration guide
- **[Quick Start Guide](QUICKSTART-FRONTEND.md)** - Step-by-step manual setup
- **[Frontend Usage](docs/frontend-usage.md)** - How to use the web interface

### 🔧 Manual Setup (Alternative)

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

### 🚀 Launch & Test

```bash
./launch-frontend.sh --all    # Check status, test, and open in browser
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
- ✅ OpenAI-compatible API for easy integration
- ✅ Multiple LLM models (Mixtral, Llama-3, Phi-3)
- ✅ Health check endpoints with liveness/readiness probes
- ✅ Azure Key Vault secrets management
- ✅ Terraform & Bicep IaC
- ✅ GitHub Actions CI/CD
- ✅ Auto-scaling 0-20 GPU instances
- ✅ 40% cache hit rate
- ✅ <30s spot preemption failover

## LLM API Integration

The platform provides an **OpenAI-compatible API** for seamless integration:

```python
from openai import OpenAI

client = OpenAI(
    api_key="your-api-key",
    base_url="https://your-app.azurewebsites.net/api/v1"
)

response = client.chat.completions.create(
    model="mixtral-8x7b",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

**Available Models:**
- `mixtral-8x7b` - 32K context, fast (Mistral AI)
- `llama-3-70b` - 8K context, high quality (Meta)
- `phi-3-mini` - 4K context, lightweight (Microsoft)

**Get Connection Details:**
```bash
./setup-frontend-complete.sh  # Saves to connection-details.txt
# OR
cat connection-details.txt    # View saved connection details
```

📖 **[Complete LLM Connection Guide](docs/LLM-CONNECTION-GUIDE.md)** - API docs, examples, integration patterns

## Costs

| State | Monthly Cost |
|-------|--------------|
| Idle | ~$5 |
| Active (10 instances avg) | ~$1,100 |
| Revenue potential | ~$4,000+ |

## Documentation

- [Frontend Deployment Guide](docs/frontend-deployment.md)
- [Frontend Usage Guide](docs/frontend-usage.md)
- Deployment Guide
- API Usage
- Architecture
- Runbook