# Azure AI Inference Platform - Terraform Configuration

This directory contains the complete Terraform configuration for deploying the Azure AI Inference Arbitrage Platform.

## Architecture

The Terraform configuration deploys the following Azure resources:

### Core Infrastructure
- **Resource Group**: Container for all resources
- **Virtual Network**: Network infrastructure with subnets for VMSS and Functions
- **Network Security Group**: Security rules for VMSS access

### Compute Resources
- **VM Scale Set (VMSS)**: GPU-enabled spot instances (Standard_NC4as_T4_v3)
  - Auto-scaling from 0-20 instances
  - Spot priority with maximum price of $0.15/hour
  - Custom script extension for NVIDIA driver installation
  - Load balancer with health probes
- **Function App**: Serverless orchestration layer (Python 3.11)
  - Consumption plan for pay-per-execution
  - Integrated with Key Vault and Application Insights
  - System-assigned managed identity

### Data & Caching
- **Cosmos DB**: Serverless NoSQL database for response caching
  - Pay-per-request pricing
  - 24-hour TTL on cached responses
  - Session consistency level
- **Storage Account**: Blob storage for Function App and deployments
  - Standard LRS replication
  - Private containers for deployments and cache

### API & Management
- **API Management**: Consumption tier API gateway
  - OpenAPI-compliant inference API
  - Rate limiting (1000 calls/60 seconds)
  - Integration with Function App backend
  - Subscription-based authentication

### Security & Secrets
- **Key Vault**: Centralized secrets management
  - RBAC authorization enabled
  - Stores API keys, connection strings
  - 7-day soft delete retention
  - Integrated with Function App and APIM

### Monitoring & Observability
- **Log Analytics Workspace**: Centralized logging (30-day retention)
- **Application Insights**: APM and telemetry
  - Connected to Function App and APIM
  - Instrumentation keys stored in Key Vault

## Prerequisites

1. **Azure CLI**: Install from https://aka.ms/installazurecli
2. **Terraform**: v1.5.0 or later
3. **Azure Subscription**: With appropriate permissions
4. **Quotas**: Ensure you have quota for GPU VMs (Standard_NC4as_T4_v3)

## Configuration

### Required Variables

Create a `terraform.tfvars` file (or copy from `terraform.tfvars.example`):

```hcl
project_name = "ai-inference"
environment  = "prod"
location     = "eastus"
admin_email  = "your-email@example.com"

# Security Configuration (IMPORTANT for production)
# Restrict CORS to specific domains
allowed_cors_origins = [
  "https://yourdomain.com",
  "https://app.yourdomain.com"
]

# Restrict SSH access to management IPs only
allowed_ssh_source_addresses = [
  "203.0.113.0/24"  # Your office IP range
]

# Set a secure admin password or use SSH keys
vmss_admin_password = "YourSecurePassword!123"

# Optional: Customize VMSS settings
vmss_sku                   = "Standard_NC4as_T4_v3"
vmss_spot_max_price        = 0.15
vmss_min_instances         = 0
vmss_max_instances         = 20
vmss_nvidia_driver_version = "535"
```

### Optional: SSH Key for VMSS

For SSH access to VMSS instances, generate an SSH key:

```bash
ssh-keygen -t rsa -b 4096 -f terraform/ssh_key -N ""
```

Then uncomment the SSH key configuration in `vmss.tf` and comment out the password authentication.

### Backend Configuration

For remote state, create a `backend.tfvars`:

```hcl
storage_account_name = "your-tfstate-storage"
container_name       = "tfstate"
key                  = "ai-inference.tfstate"
resource_group_name  = "terraform-state-rg"
```

## Deployment

### Step 1: Initialize Terraform

```bash
cd terraform
terraform init
```

With remote backend:
```bash
terraform init -backend-config=backend.tfvars
```

### Step 2: Plan Deployment

```bash
terraform plan -var-file=terraform.tfvars
```

Review the execution plan to verify all resources.

### Step 3: Apply Configuration

```bash
terraform apply -var-file=terraform.tfvars
```

Confirm with `yes` when prompted.

### Step 4: View Outputs

After deployment completes:

```bash
terraform output
```

Key outputs:
- `api_endpoint`: URL for the inference API
- `function_app_url`: Function App endpoint
- `apim_gateway_url`: API Management gateway
- `deployment_summary`: Complete resource list

## Post-Deployment

### 1. Deploy Function Code

```bash
# Navigate to src directory
cd ../src

# Install Azure Functions Core Tools
npm install -g azure-functions-core-tools@4

# Deploy functions
func azure functionapp publish $(terraform output -raw function_app_name)
```

### 2. Verify Health Endpoint

```bash
APIM_URL=$(terraform output -raw apim_gateway_url)
curl "${APIM_URL}/inference/health"
```

### 3. Create API Subscription

In Azure Portal:
1. Navigate to API Management
2. Go to Subscriptions
3. Create a new subscription for the inference API
4. Copy the subscription key

### 4. Test API

```bash
SUBSCRIPTION_KEY="your-subscription-key"
curl -X POST "${APIM_URL}/inference/completions" \
  -H "Ocp-Apim-Subscription-Key: ${SUBSCRIPTION_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama-3-70b",
    "prompt": "Hello, world!",
    "max_tokens": 100
  }'
```

## Resource Management

### Scale VMSS Manually

```bash
az vmss scale \
  --name $(terraform output -raw vmss_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --new-capacity 5
```

### View VMSS Instances

```bash
az vmss list-instances \
  --name $(terraform output -raw vmss_name) \
  --resource-group $(terraform output -raw resource_group_name)
```

### Access Key Vault Secrets

```bash
az keyvault secret show \
  --vault-name $(terraform output -raw key_vault_name) \
  --name inference-api-key
```

## Monitoring

### View Logs

```bash
# Function App logs
az functionapp log tail \
  --name $(terraform output -raw function_app_name) \
  --resource-group $(terraform output -raw resource_group_name)

# Application Insights queries
az monitor app-insights query \
  --app $(terraform output -raw application_insights_name) \
  --analytics-query "requests | take 10"
```

### Cost Analysis

```bash
az consumption usage list \
  --start-date 2024-01-01 \
  --end-date 2024-01-31
```

## Cleanup

To destroy all resources:

```bash
terraform destroy -var-file=terraform.tfvars
```

**Warning**: This will permanently delete all resources and data.

## Troubleshooting

### Quota Issues

If deployment fails due to quota:
```bash
az vm list-usage --location eastus -o table | grep NC
```

Request quota increase:
```bash
az support tickets create \
  --title "GPU VM Quota Increase" \
  --quota-change ...
```

### VMSS Driver Installation

SSH into VMSS instance to check driver installation:
```bash
ssh azureuser@<vmss-instance-ip>
nvidia-smi
```

### Function App Issues

Check Function App configuration:
```bash
az functionapp config appsettings list \
  --name $(terraform output -raw function_app_name) \
  --resource-group $(terraform output -raw resource_group_name)
```

## File Structure

```
terraform/
├── main.tf               # Provider and data sources
├── variables.tf          # Input variables
├── outputs.tf            # Output values
├── resource_group.tf     # Resource group
├── keyvault.tf          # Key Vault and secrets
├── storage.tf           # Storage account
├── cosmosdb.tf          # Cosmos DB
├── network.tf           # VNet, subnets, NSG
├── vmss.tf              # VM Scale Set and autoscaling
├── function_app.tf      # Function App
├── apim.tf              # API Management
├── monitoring.tf        # Log Analytics & App Insights
├── terraform.tfvars     # Variable values (create this)
└── backend.tfvars       # Backend config (optional)
```

## Cost Estimation

| Resource | Idle Cost/Month | Active Cost/Month |
|----------|----------------|-------------------|
| Resource Group | $0 | $0 |
| Key Vault | $0.03 | $0.03 |
| Storage Account | $0.50 | $5 |
| Cosmos DB | $0.25 | $25 |
| Function App | $0 | $10 |
| VMSS (0 instances) | $0 | $0 |
| VMSS (10 instances avg) | N/A | $1,080 |
| APIM Consumption | $0 | $40 |
| VNet | $0 | $0 |
| Log Analytics | $0 | $5 |
| App Insights | $0 | $5 |
| **Total** | **~$5** | **~$1,170** |

**Revenue Potential**: ~$4,000+/month at full utilization

## Security Best Practices

### Critical Configuration (Before Production Deployment)

1. **Restrict CORS Origins**
   - Edit `allowed_cors_origins` in `terraform.tfvars`
   - Remove `["*"]` and specify exact domains
   - Example: `["https://yourdomain.com", "https://app.yourdomain.com"]`

2. **Restrict SSH Access**
   - Edit `allowed_ssh_source_addresses` in `terraform.tfvars`
   - Remove `["*"]` and specify management IPs only
   - Example: `["203.0.113.0/24", "198.51.100.10/32"]`

3. **Secure VMSS Access**
   - Set `vmss_admin_password` to a strong password, OR
   - Generate SSH keys: `ssh-keygen -t rsa -b 4096 -f terraform/ssh_key -N ""`
   - Uncomment SSH key configuration in `vmss.tf`

### General Security Practices

4. **Rotate secrets regularly** in Key Vault
5. **Enable RBAC** for all resources (already configured)
6. **Use private endpoints** for Cosmos DB and Storage in production
7. **Enable Azure Policy** compliance
8. **Configure backup** for critical data
9. **Enable DDoS protection** (set `enable_ddos_protection = true` in tfvars)
10. **Use managed identities** instead of keys where possible (already configured)
11. **Enable audit logging** on Key Vault (already configured)
12. **Use Azure Firewall** for egress filtering in production

## Support

For issues or questions:
- Azure Documentation: https://docs.microsoft.com/azure
- Terraform Azure Provider: https://registry.terraform.io/providers/hashicorp/azurerm
- Project Repository: https://github.com/imagogitter/az_rich
