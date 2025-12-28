# AI Inference Arbitrage Platform

GPU-based AI inference reselling platform with 200-300% margins using Azure spot instances.

## ⚡ Quick Start

```bash
# Option 1: Bash deployment
./deploy.sh

# Option 2: Terraform
cd terraform && terraform init && terraform apply

# Option 3: Bicep  
az deployment sub create --location eastus --template-file bicep/main.bicep
```

## 🏗️ Architecture

- **API Layer**: Azure API Management (consumption tier)
- **Compute**: VM Scale Sets with Spot priority (80% discount)
- **Models**: Llama-3-70B, Mixtral 8x7B, Phi-3-mini
- **Caching**: Azure Cosmos DB (serverless)
- **Orchestration**: Azure Functions (consumption)
- **Secrets**: Azure Key Vault

## ✅ Features

- Health check endpoints with liveness/readiness probes
- Azure Key Vault secrets management
- Terraform & Bicep IaC
- GitHub Actions CI/CD
- Auto-scaling 0-20 GPU instances
- 40% cache hit rate
- <30s spot preemption failover

## 💰 Costs

| State | Monthly Cost |
|-------|-------------|
| Idle | ~$5 |
| Active (10 instances avg) | ~$1,100 |
| Revenue potential | ~$4,000+ |

## 📖 Documentation

- [Deployment Guide](docs/deployment-guide.md)
- [API Usage](docs/api-usage.md)
- [Architecture](docs/architecture.md)
- [Runbook](docs/runbook.md)

## 🚀 Deploy

```bash
# Configure Azure CLI
az login

# Deploy infrastructure
./deploy.sh

# Deploy function code
cd src
func azure functionapp publish <function-app-name>
```

## 🔧 Configuration

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

## 📊 Monitoring

- Azure Portal: Resource groups → `<project>-rg`
- Costs: Cost Management + Billing
- Logs: Log Analytics workspace
- Metrics: Application Insights

## 🔐 Security

All secrets are stored in Azure Key Vault. Function apps and VMSS use managed identities.

## 📝 License

MIT
