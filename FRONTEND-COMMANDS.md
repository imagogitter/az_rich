# Frontend Setup & Launch Commands - Quick Reference

Complete command set for frontend setup, launch, and LLM integration.

## Table of Contents

- [Quick Start (4 Commands)](#quick-start-4-commands)
- [Complete Setup](#complete-setup)
- [Individual Commands](#individual-commands)
- [Testing & Validation](#testing--validation)
- [Connection Details](#connection-details)
- [Troubleshooting](#troubleshooting)

## Quick Start (4 Commands)

### Option A: Automated Complete Setup

```bash
# Single command - does everything
./setup-frontend-complete.sh
```

This script will:
1. ✅ Check prerequisites (Azure CLI, Docker, Terraform)
2. ✅ Deploy infrastructure (Terraform)
3. ✅ Build and deploy frontend container
4. ✅ Show connection details
5. ✅ Guide admin account creation
6. ✅ Secure the frontend
7. ✅ Test connectivity

**Time**: ~15-20 minutes

---

### Option B: Manual Step-by-Step

```bash
# 1. Deploy infrastructure
cd terraform && terraform init && terraform apply -auto-approve && cd ..

# 2. Deploy frontend
./deploy-frontend.sh

# 3. Get URL and create admin account
cd terraform && terraform output frontend_url && cd ..
# Visit URL, create admin account

# 4. Secure frontend (disable signup)
./setup-frontend-auth.sh
```

**Time**: ~15-20 minutes

---

## Complete Setup

### Prerequisites

```bash
# Check prerequisites
az --version          # Azure CLI
docker --version      # Docker
terraform version     # Terraform

# Login to Azure
az login

# Verify Docker is running
docker ps
```

### Full Infrastructure Setup

```bash
# Clone repository (if needed)
git clone https://github.com/imagogitter/az_rich.git
cd az_rich

# Initialize Terraform
cd terraform
terraform init

# Review plan
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan

# Get outputs
terraform output

cd ..
```

### Frontend Deployment

```bash
# Build and deploy frontend container
./deploy-frontend.sh

# OR manually:
cd terraform
REGISTRY_NAME=$(terraform output -raw container_registry_name)
REGISTRY_SERVER=$(terraform output -raw container_registry_login_server)
cd ..

# Login to ACR
az acr login --name $REGISTRY_NAME

# Build image
cd frontend
docker build -t open-webui:latest .

# Tag and push
docker tag open-webui:latest $REGISTRY_SERVER/open-webui:latest
docker push $REGISTRY_SERVER/open-webui:latest

cd ..
```

### Admin Account Setup

```bash
# Get frontend URL
cd terraform
terraform output frontend_url
cd ..

# Open in browser and create account
# First user = admin!

# After creating admin, secure the frontend
./setup-frontend-auth.sh
```

### Launch & Test

```bash
# Launch frontend (with status checks)
./launch-frontend.sh

# OR specific checks:
./launch-frontend.sh --status    # Check status
./launch-frontend.sh --test      # Test connectivity
./launch-frontend.sh --info      # Show connection info
./launch-frontend.sh --open      # Open in browser
./launch-frontend.sh --all       # All of the above
```

---

## Individual Commands

### Infrastructure Management

```bash
# Initialize Terraform
cd terraform && terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy

# Show outputs
terraform output

# Specific output
terraform output frontend_url
terraform output -raw container_registry_name
```

### Frontend Container

```bash
# Build image locally
cd frontend
docker build -t open-webui:latest .

# Login to ACR
az acr login --name <registry-name>

# Tag image
docker tag open-webui:latest <registry>.azurecr.io/open-webui:latest

# Push to ACR
docker push <registry>.azurecr.io/open-webui:latest

# List images in ACR
az acr repository list --name <registry-name>

# Show image tags
az acr repository show-tags --name <registry-name> --repository open-webui
```

### Container App Management

```bash
# Show container app status
az containerapp show \
  --name <app-name> \
  --resource-group <rg-name>

# Update environment variables
az containerapp update \
  --name <app-name> \
  --resource-group <rg-name> \
  --set-env-vars "KEY=VALUE"

# Restart container app
az containerapp revision restart \
  --name <app-name> \
  --resource-group <rg-name>

# Scale container app
az containerapp update \
  --name <app-name> \
  --resource-group <rg-name> \
  --min-replicas 1 \
  --max-replicas 5

# List replicas
az containerapp replica list \
  --name <app-name> \
  --resource-group <rg-name>

# View logs
az containerapp logs show \
  --name <app-name> \
  --resource-group <rg-name> \
  --tail 100

# Follow logs (real-time)
az containerapp logs show \
  --name <app-name> \
  --resource-group <rg-name> \
  --tail 100 \
  --follow
```

### Secrets & Key Vault

```bash
# Get API key
az keyvault secret show \
  --vault-name <key-vault-name> \
  --name "frontend-openai-api-key" \
  --query value -o tsv

# Set secret
az keyvault secret set \
  --vault-name <key-vault-name> \
  --name "secret-name" \
  --value "secret-value"

# List secrets
az keyvault secret list \
  --vault-name <key-vault-name>

# Delete secret
az keyvault secret delete \
  --vault-name <key-vault-name> \
  --name "secret-name"
```

### Backend Function App

```bash
# Deploy backend
./deploy.sh

# Show function app status
az functionapp show \
  --name <function-app-name> \
  --resource-group <rg-name>

# Start function app
az functionapp start \
  --name <function-app-name> \
  --resource-group <rg-name>

# Stop function app
az functionapp stop \
  --name <function-app-name> \
  --resource-group <rg-name>

# Restart function app
az functionapp restart \
  --name <function-app-name> \
  --resource-group <rg-name>

# View function app logs
az functionapp log tail \
  --name <function-app-name> \
  --resource-group <rg-name>

# Get function app URL
az functionapp show \
  --name <function-app-name> \
  --resource-group <rg-name> \
  --query defaultHostName -o tsv
```

---

## Testing & Validation

### Frontend Tests

```bash
# Test frontend URL
curl -I https://<frontend-url>

# Full response
curl -L https://<frontend-url>

# Check with timeout
curl -L --max-time 30 https://<frontend-url>
```

### Backend API Tests

```bash
# Get backend URL
cd terraform
BACKEND_URL=$(az functionapp show \
  --name $(terraform output -raw function_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --query defaultHostName -o tsv)
cd ..

# Test health endpoint
curl https://$BACKEND_URL/api/v1/health

# List models
API_KEY=$(az keyvault secret show \
  --vault-name <key-vault-name> \
  --name "frontend-openai-api-key" \
  --query value -o tsv)

curl https://$BACKEND_URL/api/v1/models \
  -H "Authorization: Bearer $API_KEY"

# Test chat completion
curl -X POST https://$BACKEND_URL/api/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "mixtral-8x7b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 50
  }'
```

### Connection Test Script

```bash
# Create test script
cat > test-connection.sh << 'EOF'
#!/bin/bash
set -euo pipefail

cd terraform
BACKEND_URL=$(az functionapp show \
  --name $(terraform output -raw function_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --query defaultHostName -o tsv)

API_KEY=$(az keyvault secret show \
  --vault-name $(terraform output -raw key_vault_name) \
  --name "frontend-openai-api-key" \
  --query value -o tsv)

FRONTEND_URL=$(terraform output -raw frontend_url)
cd ..

echo "Testing Frontend: $FRONTEND_URL"
curl -I -L --max-time 30 "$FRONTEND_URL"

echo ""
echo "Testing Backend: https://$BACKEND_URL/api/v1/health"
curl -s "https://$BACKEND_URL/api/v1/health"

echo ""
echo "Testing Models API:"
curl -s "https://$BACKEND_URL/api/v1/models" \
  -H "Authorization: Bearer $API_KEY" | jq '.data[].id'

echo ""
echo "All tests passed!"
EOF

chmod +x test-connection.sh
./test-connection.sh
```

---

## Connection Details

### Retrieve All Connection Info

```bash
# Option 1: From setup script output
cat connection-details.txt

# Option 2: Manually retrieve
cd terraform

# Frontend URL
terraform output frontend_url

# Resource group
terraform output -raw resource_group_name

# Backend URL
az functionapp show \
  --name $(terraform output -raw function_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --query defaultHostName -o tsv

# API Key
az keyvault secret show \
  --vault-name $(terraform output -raw key_vault_name) \
  --name "frontend-openai-api-key" \
  --query value -o tsv

cd ..
```

### Create .env File

```bash
cat > .env << EOF
# AI Inference Platform Configuration
FRONTEND_URL=$(cd terraform && terraform output -raw frontend_url && cd ..)
BACKEND_URL=https://$(cd terraform && az functionapp show --name $(terraform output -raw function_app_name) --resource-group $(terraform output -raw resource_group_name) --query defaultHostName -o tsv && cd ..)/api/v1
API_KEY=$(cd terraform && az keyvault secret show --vault-name $(terraform output -raw key_vault_name) --name "frontend-openai-api-key" --query value -o tsv && cd ..)
DEFAULT_MODEL=mixtral-8x7b
EOF

# Load environment
source .env
```

---

## Troubleshooting

### Common Issues & Solutions

#### 1. Terraform Errors

```bash
# Reinitialize
cd terraform
rm -rf .terraform
terraform init

# Fix state lock
terraform force-unlock <lock-id>

# Import existing resource
terraform import azurerm_resource_group.main /subscriptions/<sub-id>/resourceGroups/<rg-name>
```

#### 2. Docker Build Fails

```bash
# Clean Docker cache
docker system prune -a

# Rebuild without cache
cd frontend
docker build --no-cache -t open-webui:latest .

# Check Docker daemon
docker ps
```

#### 3. Cannot Login to ACR

```bash
# Refresh login
az acr login --name <registry-name>

# Use admin credentials
az acr credential show --name <registry-name>

# Manual docker login
docker login <registry>.azurecr.io \
  -u <username> \
  -p <password>
```

#### 4. Container App Not Starting

```bash
# Check logs
az containerapp logs show \
  --name <app-name> \
  --resource-group <rg-name> \
  --tail 100

# Check revision status
az containerapp revision list \
  --name <app-name> \
  --resource-group <rg-name>

# Restart
az containerapp revision restart \
  --name <app-name> \
  --resource-group <rg-name>
```

#### 5. Frontend Not Accessible

```bash
# Wait for DNS propagation (1-2 minutes)
sleep 120

# Test directly
curl -I https://<frontend-url>

# Check container status
az containerapp show \
  --name <app-name> \
  --resource-group <rg-name> \
  --query "properties.provisioningState"
```

#### 6. Backend Connection Error

```bash
# Check function app
az functionapp show \
  --name <function-app-name> \
  --resource-group <rg-name> \
  --query "state"

# Deploy backend if not deployed
./deploy.sh

# Test health
curl https://<function-app>.azurewebsites.net/api/v1/health
```

### Debug Commands

```bash
# Get all resource info
az resource list --resource-group <rg-name> --output table

# Check resource group
az group show --name <rg-name>

# Check subscription
az account show

# List container apps
az containerapp list --resource-group <rg-name> --output table

# List function apps
az functionapp list --resource-group <rg-name> --output table

# Check Key Vault access
az keyvault show --name <key-vault-name>
```

### Reset & Cleanup

```bash
# Remove all resources
cd terraform
terraform destroy -auto-approve

# Clean local Docker
docker system prune -a -f

# Clean Terraform state
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*

# Start fresh
terraform init
terraform apply
```

---

## Quick Reference Card

### Essential Commands

```bash
# Setup
./setup-frontend-complete.sh          # Complete setup

# Launch
./launch-frontend.sh --all            # Launch & test

# Deploy
cd terraform && terraform apply       # Infrastructure
./deploy-frontend.sh                  # Frontend
./deploy.sh                           # Backend

# Status
./launch-frontend.sh --status         # Check status
terraform output                      # Show all outputs

# Logs
az containerapp logs show --name <app> --resource-group <rg> --tail 100

# Test
curl https://<backend>/api/v1/health  # Health check
```

### Get Connection Details

```bash
cd terraform
echo "Frontend: $(terraform output -raw frontend_url)"
echo "Backend: https://$(az functionapp show --name $(terraform output -raw function_app_name) --resource-group $(terraform output -raw resource_group_name) --query defaultHostName -o tsv)/api/v1"
echo "API Key: $(az keyvault secret show --vault-name $(terraform output -raw key_vault_name) --name "frontend-openai-api-key" --query value -o tsv)"
cd ..
```

### Models

```
mixtral-8x7b   # 32K context, fast
llama-3-70b    # 8K context, high quality  
phi-3-mini     # 4K context, lightweight
```

---

## Additional Resources

- **Full LLM Guide**: [docs/LLM-CONNECTION-GUIDE.md](docs/LLM-CONNECTION-GUIDE.md)
- **Frontend Usage**: [docs/frontend-usage.md](docs/frontend-usage.md)
- **Quick Start**: [QUICKSTART-FRONTEND.md](QUICKSTART-FRONTEND.md)
- **API Spec**: [openapi.json](openapi.json)

---

**Last Updated**: 2024-01-17
**Version**: 1.0
