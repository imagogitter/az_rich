# Terraform Deployment Workflow

This document describes the automated Terraform deployment workflow for the az_rich infrastructure.

## Overview

The `terraform-deploy.yml` workflow automates the deployment of Azure infrastructure using Terraform. It provides:

- Automated validation and planning on every push and pull request
- Manual approval requirement for applying changes to production
- Comprehensive error handling and status reporting
- Secure authentication using Azure Service Principal

## Workflow Triggers

The workflow runs on:
- **Push to main branch**: Runs plan and apply (with approval)
- **Pull requests to main**: Runs plan only and comments results on PR

## Required GitHub Secrets

Before using this workflow, configure the following secrets in your GitHub repository:

1. **AZURE_CLIENT_ID**: Service Principal Application (Client) ID
2. **AZURE_CLIENT_SECRET**: Service Principal Client Secret  
3. **AZURE_TENANT_ID**: Azure AD Tenant ID
4. **AZURE_SUBSCRIPTION_ID**: Azure Subscription ID

### Creating Azure Service Principal

```bash
# Create a service principal with Contributor role
az ad sp create-for-rbac \
  --name "github-actions-terraform" \
  --role Contributor \
  --scopes /subscriptions/{subscription-id} \
  --sdk-auth

# The output will contain the values needed for GitHub secrets:
# - clientId -> AZURE_CLIENT_ID
# - clientSecret -> AZURE_CLIENT_SECRET
# - tenantId -> AZURE_TENANT_ID
# - subscriptionId -> AZURE_SUBSCRIPTION_ID
```

### Adding Secrets to GitHub

1. Go to your repository on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add each of the four required secrets

## Environment Protection

To enable manual approval for Terraform apply operations:

1. Go to Settings → Environments
2. Create an environment named `production`
3. Enable "Required reviewers" protection rule
4. Add team members who should approve deployments
5. Save the protection rules

With this configuration, the `terraform-apply` job will wait for manual approval before executing.

## Workflow Jobs

### 1. terraform-plan

Runs on all pushes and pull requests to main:

- Checks out code
- Sets up Terraform CLI (version 1.5.0)
- Authenticates to Azure using service principal
- Initializes Terraform backend
- Validates Terraform configuration
- Generates execution plan
- Saves plan artifact (for push events)
- Comments plan on PR (for pull request events)

### 2. terraform-apply

Runs only on pushes to main branch (requires manual approval):

- Checks out code
- Sets up Terraform CLI
- Authenticates to Azure
- Downloads plan artifact from previous job
- Initializes Terraform backend
- Applies the Terraform plan
- Uploads Terraform outputs as artifact
- Generates deployment summary

## Error Handling

The workflow includes comprehensive error handling:

- **Init Failure**: Reports backend configuration or credential issues
- **Validate Failure**: Reports syntax errors in Terraform files
- **Plan Failure**: Reports planning errors with detailed logs
- **Apply Failure**: Reports apply errors with critical warning

Each step uses `set -e` to fail fast on errors and provides descriptive error messages.

## Best Practices Implemented

1. **Security**:
   - Uses service principal authentication
   - Secrets stored in GitHub repository secrets
   - No credentials in workflow code
   - Minimal permissions (principle of least privilege)

2. **Reliability**:
   - Plan artifact saved and reused in apply job
   - Terraform state managed via Azure backend
   - Error handling at each step
   - Explicit status checks

3. **Visibility**:
   - PR comments with plan output
   - GitHub Actions summary for deployments
   - Terraform outputs saved as artifacts
   - Grouped log output for readability

4. **Governance**:
   - Manual approval required for production changes
   - Separate plan and apply jobs
   - Read-only permissions for plan job
   - Environment-based deployment controls

## Terraform Backend Configuration

The workflow assumes Terraform backend is configured in `terraform/main.tf`. Example backend configuration:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstatestorage"
    container_name       = "tfstate"
    key                  = "ai-inference.tfstate"
  }
}
```

Ensure the backend storage account exists and the service principal has access to it.

## Troubleshooting

### Workflow fails at init step

**Issue**: Backend configuration or credentials problem

**Solution**: 
- Verify all four Azure secrets are correctly set
- Ensure service principal has access to Terraform state storage
- Check backend configuration in `terraform/main.tf`

### Workflow fails at validate step

**Issue**: Syntax errors in Terraform configuration

**Solution**:
- Run `terraform validate` locally
- Fix any reported syntax errors
- Commit and push the fixes

### Workflow fails at plan step

**Issue**: Resource conflicts or configuration errors

**Solution**:
- Review the plan output in workflow logs
- Fix resource configuration issues
- Ensure required variables are set

### Apply waits indefinitely

**Issue**: Environment protection rules require approval

**Solution**:
- Go to Actions tab in GitHub
- Find the waiting workflow run
- Click "Review deployments"
- Approve or reject the deployment

## Monitoring

After successful deployment:

1. Check Terraform outputs in workflow artifacts
2. Verify resources in Azure Portal
3. Review deployment summary in workflow logs
4. Monitor Azure resources for proper operation

## Maintenance

Regular maintenance tasks:

- Update Terraform version in workflow as needed
- Rotate service principal credentials periodically
- Review and update environment protection rules
- Clean up old workflow artifacts (automatic after retention period)
