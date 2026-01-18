# Complete Azure Deployment Guide

This comprehensive guide covers deploying all resources for the AI Inference Arbitrage Platform on Azure and retrieving detailed deployment information including endpoints, API keys, and model configurations.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Deployment](#quick-deployment)
3. [Detailed Deployment Steps](#detailed-deployment-steps)
4. [Getting Deployment Details](#getting-deployment-details)
5. [Resource Overview](#resource-overview)
6. [API Endpoints](#api-endpoints)
7. [Authentication & API Keys](#authentication--api-keys)
8. [Available Models](#available-models)
9. [Usage Examples](#usage-examples)
10. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

- **Azure CLI** (v2.50+): [Installation Guide](https://learn.microsoft.com/cli/azure/install-azure-cli)
- **Terraform** (v1.5+): [Installation Guide](https://www.terraform.io/downloads)
- **Docker** (for frontend deployment): [Installation Guide](https://docs.docker.com/get-docker/)
- **Git**: For cloning the repository

### Azure Requirements

- Active Azure subscription
- Sufficient permissions to create resources
- GPU quota for VM Scale Sets (Standard_NC4as_T4_v3)
- Service Principal for automated deployments (optional)

### Login to Azure

```bash
az login
az account set --subscription <your-subscription-id>
```

## Quick Deployment

### Option 1: Complete Automated Deployment

Deploy everything with a single command:

```bash
./setup-frontend-complete.sh
```

This script will:
1. Deploy all infrastructure using Terraform
2. Build and deploy the frontend container
3. Display comprehensive deployment details

### Option 2: GitHub Actions (CI/CD)

1. Configure repository secrets:
   - `AZURE_CREDENTIALS`: Service principal JSON

2. Push to `main` branch or manually trigger "Frontend Deployment" workflow

3. Download artifacts containing deployment details

## Detailed Deployment Steps

### Step 1: Clone Repository

```bash
git clone https://github.com/imagogitter/az_rich.git
cd az_rich
```

### Step 2: Configure Variables (Optional)

Edit `terraform/variables.tf` or create `terraform/terraform.tfvars`:

```hcl
project_name           = "ai-inference"
environment            = "prod"
location               = "eastus"
admin_email            = "admin@yourdomain.com"
vmss_sku               = "Standard_NC4as_T4_v3"
vmss_spot_max_price    = 0.15
vmss_min_instances     = 0
vmss_max_instances     = 20
```

### Step 3: Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply
```

This creates:
- ✅ Resource Group
- ✅ Key Vault (for secrets)
- ✅ Cosmos DB (serverless, for caching)
- ✅ Storage Account
- ✅ Azure Functions (with Python 3.11 runtime)
- ✅ Application Insights & Log Analytics
- ✅ API Management (consumption tier)
- ✅ VM Scale Set with GPU instances (spot priority)
- ✅ Virtual Network & Network Security Group
- ✅ Container Registry
- ✅ Container App Environment
- ✅ Container App (frontend)
- ✅ Autoscaling configuration

### Step 4: Deploy Function App Code

```bash
cd ..

# Package function code
cd src
zip -r ../function.zip .
cd ..

# Get resource names
RESOURCE_GROUP=$(cd terraform && terraform output -raw resource_group_name)
FUNCTION_APP_NAME=$(cd terraform && terraform output -raw function_app_name)

# Deploy to Azure Functions
az functionapp deployment source config-zip \
  --resource-group $RESOURCE_GROUP \
  --name $FUNCTION_APP_NAME \
  --src function.zip
```

### Step 5: Deploy Frontend (Optional)

```bash
./deploy-frontend.sh
```

Or manually:

```bash
# Get registry details
REGISTRY_NAME=$(cd terraform && terraform output -raw container_registry_name)
REGISTRY_LOGIN_SERVER=$(cd terraform && terraform output -raw container_registry_login_server)

# Login to ACR
az acr login --name $REGISTRY_NAME

# Build and push frontend
cd frontend
docker build -t open-webui:latest .
docker tag open-webui:latest ${REGISTRY_LOGIN_SERVER}/open-webui:latest
docker push ${REGISTRY_LOGIN_SERVER}/open-webui:latest
```

## Getting Deployment Details

### Automated Details Script

After deployment, retrieve comprehensive deployment details:

```bash
# Human-readable format
./scripts/get-deployment-details.sh

# JSON format (for automation)
./scripts/get-deployment-details.sh --json > deployment-info.json

# Markdown format (for documentation)
./scripts/get-deployment-details.sh --markdown > DEPLOYMENT-INFO.md
```

The script provides:
- ✅ All API endpoints
- ✅ Resource URLs
- ✅ API key locations
- ✅ Model information
- ✅ Resource status
- ✅ Usage examples
- ✅ Useful commands

### Manual Details Retrieval

#### Get Terraform Outputs

```bash
cd terraform

# All outputs
terraform output

# Specific outputs
terraform output resource_group_name
terraform output frontend_url
terraform output function_app_name
terraform output key_vault_name
```

#### Get API Keys from Key Vault

```bash
KEY_VAULT_NAME=$(cd terraform && terraform output -raw key_vault_name)

# Frontend API key
az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name frontend-openai-api-key \
  --query value -o tsv

# Inference API key (if exists)
az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name inference-api-key \
  --query value -o tsv

# List all secrets
az keyvault secret list --vault-name $KEY_VAULT_NAME --query "[].name" -o table
```

## Resource Overview

### Core Infrastructure

| Resource Type | Purpose | SKU/Tier |
|--------------|---------|----------|
| Resource Group | Container for all resources | N/A |
| Key Vault | Secrets management | Standard |
| Storage Account | Function app storage, logs | Standard_LRS |
| Cosmos DB | Response caching | Serverless |

### Compute Resources

| Resource Type | Purpose | Configuration |
|--------------|---------|---------------|
| Azure Functions | API orchestration, health checks | Consumption, Python 3.11 |
| VM Scale Set | GPU inference workloads | Standard_NC4as_T4_v3, Spot, 0-20 instances |
| Container App | Frontend web UI (Open WebUI) | 0.5 CPU, 1Gi RAM, 0-3 replicas |

### API & Networking

| Resource Type | Purpose | Configuration |
|--------------|---------|---------------|
| API Management | API gateway, rate limiting | Consumption tier |
| Virtual Network | Private networking for VMSS | 10.0.0.0/16 |
| Network Security Group | Security rules | Restrictive inbound rules |
| Container Registry | Frontend image storage | Basic tier |

### Monitoring

| Resource Type | Purpose | Configuration |
|--------------|---------|---------------|
| Application Insights | Telemetry, logging | Web application type |
| Log Analytics | Log aggregation | PerGB2018, 30-day retention |
| Monitor Alerts | Proactive monitoring | Action groups for email |

## API Endpoints

### Base URLs

After deployment, your API endpoints will be:

```
Function App:   https://<function-app-name>.azurewebsites.net
API Base:       https://<function-app-name>.azurewebsites.net/api
APIM Gateway:   https://<apim-name>.azure-api.net
Frontend:       https://<frontend-app-name>.<region>.azurecontainerapps.io
```

### Endpoint Reference

| Endpoint | Method | Purpose | Authentication |
|----------|--------|---------|----------------|
| `/api/v1/chat/completions` | POST | Generate chat completions | Bearer token |
| `/api/v1/models` | GET | List available models | Bearer token |
| `/api/health/live` | GET | Liveness probe | None |
| `/api/health/ready` | GET | Readiness probe | None |
| `/api/health/startup` | GET | Startup probe | None |

### Health Check Endpoints

```bash
# Liveness - Is the service alive?
curl https://<function-app>.azurewebsites.net/api/health/live

# Readiness - Is the service ready to accept traffic?
curl https://<function-app>.azurewebsites.net/api/health/ready

# Expected response (healthy):
{
  "status": "healthy",
  "timestamp": "2026-01-18T18:00:00Z",
  "version": "1.0.0",
  "checks": {
    "cosmos_db": {"status": "healthy", "latency_ms": 45},
    "key_vault": {"status": "healthy", "latency_ms": 23}
  }
}
```

## Authentication & API Keys

### Key Vault Secrets

All sensitive credentials are stored in Azure Key Vault:

| Secret Name | Purpose |
|------------|---------|
| `frontend-openai-api-key` | API key for frontend → backend communication |
| `inference-api-key` | API key for external API access (optional) |
| `vmss-ssh-private-key` | SSH private key for VM Scale Set management |

### Retrieving API Keys

```bash
# Set Key Vault name
KEY_VAULT_NAME=$(cd terraform && terraform output -raw key_vault_name)

# Get frontend API key
OPENAI_API_KEY=$(az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name frontend-openai-api-key \
  --query value -o tsv)

echo "Your API Key: $OPENAI_API_KEY"
```

### Using API Keys

Include the API key in the `Authorization` header:

```bash
curl -X POST https://<api-base>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -d '{"model": "mixtral-8x7b", "messages": [{"role": "user", "content": "Hello"}]}'
```

## Available Models

The platform supports three GPU-accelerated models with intelligent routing:

### Model Specifications

| Model ID | Description | Context Window | Recommended Use Case | VM SKU |
|----------|-------------|----------------|---------------------|--------|
| `llama-3-70b` | High-quality responses | 8,192 tokens | Complex reasoning, detailed answers | Standard_NC4as_T4_v3 |
| `mixtral-8x7b` | Fast and efficient | 32,768 tokens | General purpose, long context | Standard_NC4as_T4_v3 |
| `phi-3-mini` | Lightweight model | 4,096 tokens | Simple queries, quick responses | Standard_NC4as_T4_v3 |
| `auto` | Automatic selection | Variable | Let system choose based on context | N/A |

### Model Selection

```json
{
  "model": "mixtral-8x7b",  // or "llama-3-70b", "phi-3-mini", "auto"
  "messages": [
    {"role": "user", "content": "Your message here"}
  ]
}
```

### Model Parameters

Supported parameters (OpenAI-compatible):

- `temperature` (0-2): Creativity level (default: 1.0)
- `top_p` (0-1): Nucleus sampling (default: 1.0)
- `max_tokens` (1-4096): Maximum response length (default: 256)
- `stream` (boolean): Enable streaming responses (default: false)
- `stop` (string or array): Stop sequences

## Usage Examples

### cURL Examples

#### Basic Chat Completion

```bash
API_BASE="https://<function-app>.azurewebsites.net/api"
API_KEY="<your-api-key>"

curl -X POST "${API_BASE}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d '{
    "model": "mixtral-8x7b",
    "messages": [
      {"role": "user", "content": "Explain quantum computing in simple terms"}
    ],
    "max_tokens": 500,
    "temperature": 0.7
  }'
```

#### Streaming Response

```bash
curl -X POST "${API_BASE}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d '{
    "model": "mixtral-8x7b",
    "messages": [
      {"role": "user", "content": "Write a short story"}
    ],
    "stream": true
  }'
```

#### List Available Models

```bash
curl -X GET "${API_BASE}/v1/models" \
  -H "Authorization: Bearer ${API_KEY}"
```

### Python Examples

#### Using OpenAI SDK

```python
from openai import OpenAI

# Configure client
client = OpenAI(
    api_key="your-api-key",  # From Key Vault
    base_url="https://<function-app>.azurewebsites.net/api/v1"
)

# Simple completion
response = client.chat.completions.create(
    model="mixtral-8x7b",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "What is the capital of France?"}
    ],
    max_tokens=100,
    temperature=0.7
)

print(response.choices[0].message.content)
```

#### Streaming Responses

```python
stream = client.chat.completions.create(
    model="mixtral-8x7b",
    messages=[{"role": "user", "content": "Count from 1 to 10"}],
    stream=True
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")
```

#### Error Handling

```python
from openai import OpenAI, OpenAIError

client = OpenAI(
    api_key="your-api-key",
    base_url="https://<function-app>.azurewebsites.net/api/v1"
)

try:
    response = client.chat.completions.create(
        model="mixtral-8x7b",
        messages=[{"role": "user", "content": "Hello"}]
    )
    print(response.choices[0].message.content)
except OpenAIError as e:
    print(f"Error: {e}")
```

### JavaScript/TypeScript Examples

```javascript
import OpenAI from 'openai';

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
  baseURL: 'https://<function-app>.azurewebsites.net/api/v1'
});

async function chatCompletion() {
  const response = await client.chat.completions.create({
    model: 'mixtral-8x7b',
    messages: [
      { role: 'user', content: 'Hello, how are you?' }
    ],
    max_tokens: 256,
    temperature: 0.7
  });
  
  console.log(response.choices[0].message.content);
}

chatCompletion();
```

### Frontend Web UI

The platform includes Open WebUI for interactive access:

1. Navigate to: `https://<frontend-app>.azurecontainerapps.io`
2. Create admin account (first user becomes admin)
3. Configure API settings (pre-configured via environment variables)
4. Start chatting with available models

## Troubleshooting

### Check Resource Status

```bash
# Resource group
RESOURCE_GROUP=$(cd terraform && terraform output -raw resource_group_name)

# Function App status
az functionapp show \
  --name <function-app-name> \
  --resource-group $RESOURCE_GROUP \
  --query "state" -o tsv

# VMSS instance count
az vmss show \
  --name <vmss-name> \
  --resource-group $RESOURCE_GROUP \
  --query "sku.capacity" -o tsv

# Frontend status
az containerapp show \
  --name <frontend-app-name> \
  --resource-group $RESOURCE_GROUP \
  --query "properties.runningStatus" -o tsv
```

### View Logs

```bash
# Function App logs (real-time)
az functionapp log tail \
  --name <function-app-name> \
  --resource-group $RESOURCE_GROUP

# Frontend logs
az containerapp logs show \
  --name <frontend-app-name> \
  --resource-group $RESOURCE_GROUP \
  --tail 100

# Application Insights queries
az monitor app-insights query \
  --app <app-insights-name> \
  --resource-group $RESOURCE_GROUP \
  --analytics-query "requests | where timestamp > ago(1h) | summarize count() by resultCode"
```

### Common Issues

#### Issue: Terraform Init Fails

**Solution**: Ensure Azure CLI is logged in and has proper permissions.

```bash
az login
az account show
```

#### Issue: Function App Returns 500 Errors

**Possible causes**:
- Cosmos DB not accessible
- Key Vault permissions missing
- Application code not deployed

**Solution**:

```bash
# Check Function App logs
az functionapp log tail --name <function-app> --resource-group <rg>

# Verify managed identity has Key Vault access
az role assignment list \
  --assignee <function-app-principal-id> \
  --scope <key-vault-id>
```

#### Issue: VMSS Not Scaling

**Possible causes**:
- GPU quota not sufficient
- Autoscaling rules not configured
- Spot instances unavailable

**Solution**:

```bash
# Check quota
az vm list-usage --location eastus --query "[?name.value=='standardNCASv3Family']"

# Manually scale
az vmss scale \
  --name <vmss-name> \
  --resource-group <rg> \
  --new-capacity 1

# Check autoscale settings
az monitor autoscale show \
  --name <vmss-name>-autoscale \
  --resource-group <rg>
```

#### Issue: Frontend Not Accessible

**Solution**:

```bash
# Check container app status
az containerapp show \
  --name <frontend-app> \
  --resource-group <rg> \
  --query "{status:properties.runningStatus, url:properties.configuration.ingress.fqdn}"

# View recent logs
az containerapp logs show \
  --name <frontend-app> \
  --resource-group <rg> \
  --tail 50
```

#### Issue: API Returns 401 Unauthorized

**Solution**: Verify API key is correct and included in Authorization header.

```bash
# Get correct API key
KEY_VAULT_NAME=$(cd terraform && terraform output -raw key_vault_name)
az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name frontend-openai-api-key \
  --query value -o tsv

# Test with curl
curl -v -H "Authorization: Bearer <api-key>" \
  https://<function-app>.azurewebsites.net/api/health/live
```

### Performance Optimization

#### Enable Caching

Cosmos DB caching is enabled by default with 40%+ hit rate. Monitor cache performance:

```bash
# Check Cosmos DB metrics
az monitor metrics list \
  --resource <cosmos-db-id> \
  --metric "TotalRequests" \
  --aggregation Count
```

#### Scale VMSS Proactively

```bash
# Scale up before high traffic
az vmss scale \
  --name <vmss-name> \
  --resource-group <rg> \
  --new-capacity 5

# Scale down to save costs
az vmss scale \
  --name <vmss-name> \
  --resource-group <rg> \
  --new-capacity 0
```

## Cost Management

### Monitor Costs

```bash
# View resource group costs
az consumption usage list \
  --start-date 2026-01-01 \
  --end-date 2026-01-31 \
  --query "[?contains(instanceId, '<resource-group>')].{Cost:pretaxCost, Service:meterCategory}" \
  --output table
```

### Cost Optimization Tips

1. **Use Spot Instances**: 80% discount on GPU VMs (already configured)
2. **Scale to Zero**: VMSS and Container Apps scale to 0 when idle
3. **Serverless Resources**: Cosmos DB, Functions, and APIM use consumption pricing
4. **Cache Responses**: 40% cache hit rate reduces compute costs
5. **Monitor Usage**: Set up cost alerts in Azure Portal

### Estimated Monthly Costs

| State | Configuration | Est. Monthly Cost |
|-------|--------------|-------------------|
| Idle | All services at minimum | ~$5 |
| Light | 2 GPU instances (avg) | ~$250 |
| Medium | 10 GPU instances (avg) | ~$1,100 |
| Heavy | 20 GPU instances (max) | ~$2,200 |

**Revenue Potential**: 200-300% margins with spot instances

## Next Steps

1. **Test Deployment**: Use the provided examples to test your endpoints
2. **Configure Monitoring**: Set up dashboards and alerts in Azure Portal
3. **Secure Frontend**: Run `./setup-frontend-auth.sh` to disable public signup
4. **Load Testing**: Run `locust -f scripts/load_test.py` to test performance
5. **Documentation**: Review OpenAPI spec in `openapi.json`

## Support & Resources

- **OpenAPI Specification**: `openapi.json`
- **Frontend Guide**: `docs/frontend-deployment.md`
- **Production Guide**: `PRODUCTION-README.md`
- **Quick Start**: `README.md`
- **GitHub Actions**: `.github/workflows/`

## Security Best Practices

1. ✅ Store all secrets in Key Vault
2. ✅ Use Managed Identity for authentication
3. ✅ Enable HTTPS for all endpoints
4. ✅ Restrict network access with NSGs
5. ✅ Disable public signup after admin creation
6. ✅ Rotate API keys regularly
7. ✅ Monitor access logs
8. ✅ Keep dependencies updated

---

**Deployment Complete!** 🚀

For additional help, run: `./scripts/get-deployment-details.sh`
