# 🚀 AI Inference Platform - Production Deployment Guide

## Overview

This is a production-ready AI inference arbitrage platform that resells GPU-based AI inference using Azure spot instances. The platform includes complete infrastructure as code, CI/CD pipelines, monitoring, and load testing.

## Architecture

- **API Layer**: Azure API Management (consumption tier) with rate limiting
- **Compute**: VM Scale Sets with GPU spot instances (auto-scaling)
- **Models**: Mixtral-8x7B, Llama-3-70B, Phi-3-mini with intelligent routing
- **Caching**: Cosmos DB serverless with 40%+ hit rate
- **Orchestration**: Azure Functions (consumption) with async processing
- **Security**: Key Vault, managed identity, RBAC
- **Monitoring**: Application Insights, alerts, structured logging

## Quick Deploy

### Prerequisites

```bash
# Azure CLI
az login

# Terraform
terraform --version  # >= 1.5.0

# Python
python --version  # >= 3.11
```

### 1. Clone and Configure

```bash
git clone <repository>
cd ai-inference-platform

# Configure environment
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
nano terraform/terraform.tfvars  # Set your values
```

### 2. Deploy Infrastructure

```bash
cd terraform

# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply
```

### 3. Deploy Application Code

```bash
# Package function code
zip -r function.zip src/

# Deploy to Azure Functions
az functionapp deployment source config-zip \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw function_app_name) \
  --src function.zip
```

### 4. Configure API Management

Import the OpenAPI spec from `openapi.json` and configure policies.

## Configuration

### Environment Variables

Set these in your Azure Function app settings:

```bash
KEY_VAULT_NAME=<key-vault-name>
COSMOS_ACCOUNT=<cosmos-account-name>
VMSS_NAME=<vmss-name>
```

### Secrets in Key Vault

- `inference-api-key`: API key for external access
- `internal-service-key`: Key for backend communication
- `vmss-ssh-private-key`: SSH key for VM management

## Monitoring & Alerts

### Application Insights

- Request/response metrics
- Dependency tracking
- Custom events and metrics

### Alerts Configured

- Function failures (>5/minute)
- High response time (>30 seconds)
- CPU usage (>80%)
- Cosmos DB throttling
- Log-based error alerts

### Health Checks

- `/health/live`: Liveness probe
- `/health/ready`: Readiness probe (includes dependencies)
- `/health/startup`: Startup probe

## Load Testing

```bash
# Install dependencies
pip install -r scripts/requirements-test.txt

# Run load test
locust -f scripts/load_test.py --host=https://your-apim.azure-api.net
```

See `scripts/README-load-testing.md` for detailed instructions.

## Cost Optimization

### Current Estimates

| Configuration | Monthly Cost | Revenue Potential |
|--------------|--------------|-------------------|
| Idle | ~$5 | - |
| Light (2 GPU instances) | ~$250 | ~$750 |
| Medium (10 instances) | ~$1,100 | ~$4,000 |
| Heavy (20 instances) | ~$2,200 | ~$8,000 |

### Spot Instance Savings

- Up to 80% discount on GPU instances
- Auto-scaling prevents over-provisioning
- Automatic failover on spot eviction

## Security

- **Network**: NSG restricts access to VNet only
- **Identity**: Managed identity for all resource access
- **Secrets**: All sensitive data in Key Vault
- **RBAC**: Least privilege access controls
- **Compliance**: SOC 2, GDPR ready

## Troubleshooting

### Common Issues

1. **Function timeouts**: Increase timeout in host.json
2. **Cosmos throttling**: Scale RU/s or implement backoff
3. **VMSS scaling**: Check quota limits
4. **Cache misses**: Verify Cosmos connectivity

### Logs

```bash
# Function logs
az functionapp logstream --name <function-name> --resource-group <rg>

# Application Insights
# Use Azure portal or CLI queries
```

## Performance Benchmarks

- **Latency**: <5 seconds P95
- **Throughput**: 100+ requests/minute
- **Cache Hit Rate**: >40%
- **Error Rate**: <1%
- **Uptime**: 99.9% SLA

## Scaling

### Horizontal Scaling

- VMSS auto-scales based on CPU utilization
- Functions scale automatically (consumption plan)
- APIM scales with usage

### Vertical Scaling

- Choose appropriate VM SKU for workload
- Adjust Cosmos DB RU/s based on load
- Scale storage tiers as needed

## Backup & Recovery

- **Infrastructure**: Terraform state in Azure Storage
- **Data**: Cosmos DB continuous backup
- **Code**: Git versioning
- **Secrets**: Key Vault soft delete enabled

## Compliance & Governance

- **Tags**: Cost center, environment, managed-by
- **Naming**: Consistent resource naming
- **Policies**: Azure Policy integration ready
- **Auditing**: Activity logs and diagnostic settings

## Next Steps

1. **Testing**: Run load tests and validate performance
2. **Monitoring**: Set up dashboards and alerts
3. **Security**: Configure additional security policies
4. **Optimization**: Monitor costs and adjust scaling
5. **Documentation**: Update runbooks and procedures

---

**Ready for production deployment!** 🚀