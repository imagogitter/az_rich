# GitHub Actions Workflow Failure Diagnosis

## Issue Summary

The GitHub Actions workflows are failing **not due to syntax or YAML formatting issues**, but because the required Azure credentials are not configured as GitHub repository secrets.

## Root Cause

The workflows reference the following secrets that are currently not set or are empty:
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_CREDENTIALS` (for frontend-deploy.yml)

## Evidence from Failed Workflow Run

From the Terraform Deployment workflow run (ID: 21121642302):

```
##[error]Login failed with Error: Not all parameters are provided in 'creds'. 
Double-check if all keys are defined in 'creds': 'clientId', 'clientSecret', 'tenantId'.
```

This error occurs at the "Azure Login with Service Principal" step because the secrets are not configured.

## How to Fix

### Step 1: Create an Azure Service Principal

Run the following Azure CLI command to create a service principal:

```bash
az ad sp create-for-rbac \
  --name "github-actions-az-rich" \
  --role contributor \
  --scopes /subscriptions/{subscription-id} \
  --sdk-auth
```

This will output JSON containing the credentials you need.

### Step 2: Configure GitHub Secrets

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add each of the following:

#### For terraform-deploy.yml:
- **Name:** `AZURE_CLIENT_ID`
  - **Value:** The `clientId` from the service principal output
  
- **Name:** `AZURE_CLIENT_SECRET`
  - **Value:** The `clientSecret` from the service principal output
  
- **Name:** `AZURE_TENANT_ID`
  - **Value:** The `tenantId` from the service principal output
  
- **Name:** `AZURE_SUBSCRIPTION_ID`
  - **Value:** The `subscriptionId` from the service principal output

#### For frontend-deploy.yml:
- **Name:** `AZURE_CREDENTIALS`
  - **Value:** The entire JSON output from the service principal creation command

Example AZURE_CREDENTIALS format:
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "your-client-secret",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

### Step 3: Verify the Configuration

After configuring the secrets:
1. Re-run the failed workflow
2. The Azure login step should succeed
3. The Terraform operations should be able to proceed

## Workflow Files Status

✅ All workflow files have correct syntax and structure
✅ Action versions are properly standardized
✅ YAML formatting is valid
❌ GitHub repository secrets are not configured (blocking execution)

## Next Steps

1. Configure the Azure credentials as GitHub secrets (see Step 2 above)
2. Re-run the failed workflows
3. Monitor for successful Azure authentication

## Important Notes

- Keep the service principal credentials secure
- Never commit credentials to the repository
- The service principal should have minimum required permissions (contributor role on the subscription)
- Consider using separate service principals for production vs. staging environments

---

**Diagnosis Date:** 2026-01-19
**Affected Workflows:**
- terraform-deploy.yml
- frontend-deploy.yml
- full-deployment.yml
