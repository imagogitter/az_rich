# AI Inference Arbitrage Platform

GPU-based AI inference reselling platform with 200-300% margins using Azure spot instances.

## Quick Start

```bash
# Step 1: Configure all models, capabilities, and settings
./scripts/update-kilocode-settings.sh

# Step 2: Deploy using your preferred method

# Option 1: Bash deployment
./deploy.sh

# Option 2: Terraform
cd terraform && terraform init && terraform apply

# Option 3: Bicep
az deployment sub create --location eastus --template-file bicep/main.bicep
```

## Architecture

- **API Layer**: Azure API Management (consumption tier)
- **Compute**: VM Scale Sets with Spot priority (80% discount)
- **Models**: Llama-3-70B, Mixtral 8x7B, Phi-3-mini
- **Caching**: Azure Cosmos DB (serverless)
- **Orchestration**: Azure Functions (consumption)
- **Secrets**: Azure Key Vault

## Features

✅ **Idempotent Configuration Script**: Smart setup for all models and capabilities  
✅ Health check endpoints with liveness/readiness probes  
✅ Azure Key Vault secrets management  
✅ Terraform & Bicep IaC  
✅ GitHub Actions CI/CD  
✅ Auto-scaling 0-20 GPU instances  
✅ 40% cache hit rate  
✅ <30s spot preemption failover  

## Configuration

The platform includes a comprehensive configuration script that sets up all models, capabilities, and settings:

```bash
# Full configuration update (idempotent)
./scripts/update-kilocode-settings.sh

# Verify configuration only
./scripts/update-kilocode-settings.sh --verify-only

# Check service health
./scripts/update-kilocode-settings.sh --check-health http://localhost:7071/api/health/live
```

**Configured Models:**
- Mixtral-8x7B (32K context, $0.002/1K tokens)
- Llama-3-70B (8K context, $0.003/1K tokens)
- Phi-3-mini (4K context, $0.0005/1K tokens)

**Enabled Capabilities:**
- Streaming responses
- Response caching (40% hit rate target)
- Health checks (Kubernetes-style)
- Auto-scaling (0-20 instances)
- Spot instance failover (<30s)
- Rate limiting

See [Configuration Script Documentation](scripts/README-kilocode-settings.md) for details.
## Costs

| State | Monthly Cost |
|-------|--------------|
| Idle | ~$5 |
| Active (10 instances avg) | ~$1,100 |
| Revenue potential | ~$4,000+ |

## Documentation

- [Configuration Script](scripts/README-kilocode-settings.md) - Complete configuration management
- Deployment Guide
- API Usage
- Architecture
- Runbook