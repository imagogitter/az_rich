# Azure Deployment Guide

## Overview

This guide covers deploying the AI Inference Platform to Azure using GitHub Actions workflows. The deployment is designed to be **idempotent** (can run multiple times safely) and **fully automated**.

## Prerequisites

### Required GitHub Secrets

Configure the following secrets in your GitHub repository (Settings → Secrets and variables → Actions):

1. **AZURE_CREDENTIALS** (Required for all workflows)
   ```json
   {
     "clientId": "YOUR_SERVICE_PRINCIPAL_CLIENT_ID",
     "clientSecret": "YOUR_SERVICE_PRINCIPAL_SECRET",
     "tenantId": "YOUR_AZURE_AD_TENANT_ID",
     "subscriptionId": "YOUR_AZURE_SUBSCRIPTION_ID"
   }
   ```

2. **AZURE_FUNCTIONAPP_PUBLISH_PROFILE** (Optional - used as fallback for function deployment)
   - Download from Azure Portal → Function App → Get publish profile

### Azure Service Principal Setup

Create a service principal with contributor access:

```bash
# Create service principal
az ad sp create-for-rbac \
  --name "github-actions-sp" \
  --role Contributor \
  --scopes /subscriptions/{subscription-id} \
  --sdk-auth

# Output will be the JSON for AZURE_CREDENTIALS secret
```

## Deployment Workflows

### 1. Full Deployment Workflow (`full-deployment.yml`)

**Recommended for initial deployments and complete updates**

This workflow deploys:
- Azure infrastructure (Terraform)
- Azure Functions (Python backend)
- Frontend (Container App)
- Provides detailed deployment information

**Triggers:**
- Manual dispatch (workflow_dispatch) - recommended
- Push to main (automatic on code changes)

**Usage:**
```bash
# Via GitHub UI: Actions → Full Azure Deployment with Details → Run workflow

# Or via GitHub CLI:
gh workflow run full-deployment.yml \
  -f environment=prod \
  -f deploy_infrastructure=true \
  -f deploy_functions=true \
  -f deploy_frontend=true
```

**What it does:**
1. Validates Terraform configuration
2. Runs linting and tests on Python code
3. Deploys infrastructure (if enabled)
4. Deploys Azure Functions (if enabled)
5. Builds and deploys frontend container (if enabled)
6. Generates comprehensive deployment details
7. Verifies all resources are deployed correctly

**Outputs:**
- Deployment summary in GitHub Actions summary
- Downloadable artifacts with:
  - Terraform state files
  - Deployment details (JSON, Markdown, Text)
  - API credentials
  - Connection information

### 2. Terraform Deployment Workflow (`terraform-deploy.yml`)

**Recommended for infrastructure-only changes**

**Triggers:**
- Push to main (Terraform or workflow file changes)
- Pull requests (plan only)

**Features:**
- Terraform plan on PR (with automatic PR comment)
- Terraform apply on merge to main (with manual approval)
- Production environment protection

**Usage:**
```bash
# Automatic on PR - shows plan in PR comments
# Manual approval required for apply on merge to main
```

### 3. Frontend Deployment Workflow (`frontend-deploy.yml`)

**Recommended for frontend-only updates**

**Triggers:**
- Push to main (frontend or Terraform changes)
- Manual dispatch

**Usage:**
```bash
gh workflow run frontend-deploy.yml -f environment=production
```

## State Management

### How State Works

The workflows use **local Terraform backend** with **GitHub Actions artifacts** for state persistence:

- Each environment (prod, staging, dev) has its own state artifact
- State is saved after successful deployments
- State is restored before each deployment (idempotency)
- State artifacts are retained for 90 days

This approach provides:
- ✅ Idempotent deployments (can rerun safely)
- ✅ No external dependencies (no storage account needed)
- ✅ Environment isolation
- ✅ State history via artifacts

### Remote Backend (Optional)

For production use with multiple users, configure remote state:

```bash
# 1. Create storage account
az storage account create \
  --name tfstatestorageXXXXX \
  --resource-group terraform-state-rg \
  --location eastus \
  --sku Standard_LRS

# 2. Create container
az storage container create \
  --name tfstate \
  --account-name tfstatestorageXXXXX

# 3. Update terraform/main.tf backend block
# 4. Initialize backend
cd terraform
terraform init \
  -backend-config="storage_account_name=tfstatestorageXXXXX" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=ai-inference.tfstate"
```

## Troubleshooting

### Common Issues

#### 1. "Backend initialization required"

**Cause:** Terraform backend configuration mismatch

**Solution:**
- Workflows are configured to use local backend
- No action needed - this is fixed in recent commits
- If you see this error, ensure you're using the latest workflow version

#### 2. "AZURE_CREDENTIALS secret not found"

**Cause:** GitHub secret not configured

**Solution:**
```bash
# Create service principal and save output
az ad sp create-for-rbac --name "github-actions" --role Contributor --scopes /subscriptions/{id} --sdk-auth

# Add output as AZURE_CREDENTIALS secret in GitHub
```

#### 3. "Terraform outputs empty after restore"

**Cause:** State artifact from previous run not found (first deployment)

**Solution:**
- This is normal for first deployment
- Subsequent runs will restore state correctly

#### 4. "Resources already exist" errors

**Cause:** Previous partial deployment

**Solution:**
```bash
# Check existing resources
az resource list --resource-group ai-inference-prod-rg

# Either:
# A) Manually delete conflicting resources, or
# B) Import them into Terraform state
```

#### 5. Function deployment fails

**Cause:** Publish profile or credentials issue

**Solution:**
- Primary method uses Azure CLI (AZURE_CREDENTIALS)
- Fallback uses publish profile (AZURE_FUNCTIONAPP_PUBLISH_PROFILE)
- Ensure at least AZURE_CREDENTIALS is configured

### Debug Tips

1. **View workflow logs:** Actions tab → Select run → View job logs

2. **Download artifacts:** Failed runs often save debug info in artifacts

3. **Check Azure Portal:** Verify resources are created in expected resource group

4. **Terraform state issues:**
   ```bash
   # Download state artifact from GitHub Actions
   # Then locally:
   terraform show terraform.tfstate
   ```

## Deployment Verification

After successful deployment:

### 1. Check GitHub Actions Summary
- View deployment summary with all URLs and credentials
- Download artifacts for detailed information

### 2. Verify API Endpoints
```bash
# Get API key from Key Vault
API_KEY=$(az keyvault secret show \
  --vault-name {key-vault-name} \
  --name frontend-openai-api-key \
  --query value -o tsv)

# Test health endpoint
curl https://{function-app-name}.azurewebsites.net/api/health/live

# Test chat completions
curl -X POST https://{function-app-name}.azurewebsites.net/api/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d '{
    "model": "mixtral-8x7b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 50
  }'
```

### 3. Access Frontend
- Navigate to frontend URL from deployment summary
- Create admin account (first user becomes admin)
- Configure API settings

## Environment-Specific Deployments

### Deploy to Staging
```bash
gh workflow run full-deployment.yml \
  -f environment=staging \
  -f deploy_infrastructure=true \
  -f deploy_functions=true \
  -f deploy_frontend=true
```

### Deploy to Development
```bash
gh workflow run full-deployment.yml \
  -f environment=dev \
  -f deploy_infrastructure=true \
  -f deploy_functions=true \
  -f deploy_frontend=true
```

Each environment:
- Has its own resource group
- Has its own state artifact
- Uses environment-specific variables
- Can be deployed independently

## Best Practices

1. **Use manual dispatch for first deployment:** Easier to control and monitor

2. **Review Terraform plan before apply:** Check changes in PR comments

3. **Keep state artifacts:** Don't delete until you're sure you don't need rollback

4. **Monitor costs:** Set up Azure cost alerts after deployment

5. **Secure secrets:** Rotate service principal credentials regularly

6. **Test in dev/staging first:** Before deploying to production

7. **Document infrastructure changes:** Update Terraform files for all changes

## Cost Optimization

The platform uses:
- **Consumption tier** for Functions and APIM (pay per use)
- **Spot instances** for GPU VMs (80% discount)
- **Serverless** for Cosmos DB (pay per request)
- **Autoscaling** (0-20 instances based on demand)

Expected monthly costs (minimal usage):
- Functions: ~$10-20
- Cosmos DB: ~$1-5
- Container Apps: ~$10-15
- Storage: ~$1-2
- GPU VMs: Variable (only when active)
- **Total: ~$25-50/month** (without GPU usage)

## Support

For issues:
1. Check this guide first
2. Review workflow logs for specific errors
3. Check Azure Portal for resource status
4. Review Terraform documentation for infrastructure issues

## Related Documentation

- **OpenAPI Spec:** `openapi.json` - API documentation
- **Frontend Guide:** `docs/frontend-deployment.md` - Frontend-specific info
- **Production Guide:** `PRODUCTION-README.md` - Production best practices
- **Quick Start:** `README.md` - Getting started guide
