# AI Inference Arbitrage Platform

GPU-based AI inference reselling platform with 200-300% margins using Azure spot instances.

## Quick Start

```bash
# Option 1: Bash deployment
./deploy.sh

# Option 2: Terraform
cd terraform && terraform init && terraform apply
```

## Architecture

- **API Layer**: Azure API Management (consumption tier)
- **Compute**: VM Scale Sets with Spot priority (80% discount)
- **Models**: Llama-3-70B, Mixtral 8x7B, Phi-3-mini
- **Caching**: Azure Cosmos DB (serverless)
- **Orchestration**: Azure Functions (consumption)
- **Secrets**: Azure Key Vault

## Features

✅ Health check endpoints with liveness/readiness probes  
✅ Azure Key Vault secrets management  
✅ Terraform IaC  
✅ GitHub Actions CI/CD  
✅ Auto-scaling 0-20 GPU instances  
✅ Response caching with Cosmos DB  
✅ OpenAI-compatible API endpoints

## Costs

| State | Monthly Cost |
|-------|--------------|
| Idle | ~$5 |
| Active (10 instances avg) | ~$1,100 |
| Revenue potential | ~$4,000+ |

## Documentation

- See [ai-inference-demo/docs/](ai-inference-demo/docs/) for detailed documentation
- [Deployment Guide](ai-inference-demo/docs/deployment-guide.md)
- [API Usage](ai-inference-demo/docs/api-usage.md)