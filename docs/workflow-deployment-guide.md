# Running the Full Azure Deployment Workflow

This guide explains how to trigger and monitor the comprehensive Azure deployment workflow that deploys all resources and generates detailed deployment information.

## Quick Start

### Option 1: GitHub Web Interface (Easiest)

1. **Go to Actions tab:**
   - Navigate to: https://github.com/imagogitter/az_rich/actions/workflows/full-deployment.yml

2. **Click "Run workflow"** button (top right)

3. **Configure deployment:**
   - **Branch:** Select `copilot/ensure-resources-deployed-azure` or `main`
   - **Environment:** Choose `prod`, `staging`, or `dev`
   - **Deploy infrastructure:** ✅ (checked)
   - **Deploy functions:** ✅ (checked)
   - **Deploy frontend:** ✅ (checked)

4. **Click "Run workflow"** (green button)

5. **Monitor progress:**
   - Watch the workflow run in real-time
   - View logs for each step
   - Download artifacts when complete

### Option 2: GitHub CLI

If you have GitHub CLI installed:

```bash
# Trigger with script
./scripts/trigger-deployment.sh prod

# Or manually with gh CLI
gh workflow run full-deployment.yml \
  --ref copilot/ensure-resources-deployed-azure \
  -f environment=prod \
  -f deploy_infrastructure=true \
  -f deploy_functions=true \
  -f deploy_frontend=true

# Watch the workflow
gh run watch
```

### Option 3: Git Push (Automatic Trigger)

The workflow automatically runs on push to `main` branch:

```bash
# Merge your branch to main
git checkout main
git merge copilot/ensure-resources-deployed-azure
git push origin main

# The workflow will start automatically
```

## What the Workflow Does

### Stage 1: Validation (2-3 minutes)
- ✅ Validates Terraform configuration
- ✅ Runs code linting (Black, Flake8, MyPy)
- ✅ Executes tests (if available)
- ✅ Checks for syntax errors

### Stage 2: Infrastructure Deployment (10-15 minutes)
- ✅ Deploys Resource Group
- ✅ Creates Key Vault for secrets
- ✅ Sets up Cosmos DB (serverless)
- ✅ Configures Storage Account
- ✅ Deploys Azure Functions infrastructure
- ✅ Creates Application Insights & Log Analytics
- ✅ Sets up API Management (consumption tier)
- ✅ Configures VM Scale Set with GPU instances
- ✅ Creates Virtual Network & NSG
- ✅ Sets up Container Registry
- ✅ Deploys Container App Environment
- ✅ Creates Container App (frontend)
- ✅ Configures autoscaling

### Stage 3: Function App Deployment (3-5 minutes)
- ✅ Packages Python function code
- ✅ Deploys to Azure Functions
- ✅ Configures environment variables
- ✅ Verifies health endpoints

### Stage 4: Frontend Deployment (5-7 minutes)
- ✅ Builds Docker image
- ✅ Pushes to Azure Container Registry
- ✅ Updates Container App
- ✅ Restarts frontend service

### Stage 5: Deployment Details Generation (1-2 minutes)
- ✅ Retrieves all resource information
- ✅ Extracts API endpoints
- ✅ Fetches API keys from Key Vault
- ✅ Tests health endpoints
- ✅ Generates comprehensive documentation
- ✅ Creates deployment summary
- ✅ Uploads artifacts

### Stage 6: Verification (1-2 minutes)
- ✅ Verifies all resources exist
- ✅ Checks resource health status
- ✅ Generates final status report

**Total Time:** ~25-35 minutes for complete deployment

## Prerequisites

Before running the workflow, ensure:

### 1. Azure Credentials Configured

The workflow requires `AZURE_CREDENTIALS` secret:

```bash
# Create service principal
az ad sp create-for-rbac \
  --name "github-actions-az-rich" \
  --role contributor \
  --scopes /subscriptions/<subscription-id> \
  --sdk-auth
```

Add the JSON output to GitHub Secrets:
1. Go to: https://github.com/imagogitter/az_rich/settings/secrets/actions
2. Click "New repository secret"
3. Name: `AZURE_CREDENTIALS`
4. Value: Paste the JSON output
5. Click "Add secret"

### 2. Azure Subscription Requirements

- ✅ Active Azure subscription
- ✅ Sufficient permissions (Contributor role)
- ✅ GPU quota for VM Scale Sets (Standard_NC4as_T4_v3)
- ✅ Container Apps enabled in region
- ✅ No conflicting resource names

### 3. Optional: Function App Publish Profile

For Azure Functions deployment without managed identity:

1. Download publish profile from Azure Portal
2. Add as secret: `AZURE_FUNCTIONAPP_PUBLISH_PROFILE`

## Monitoring the Workflow

### View Real-Time Progress

1. **Go to Actions tab:**
   https://github.com/imagogitter/az_rich/actions

2. **Click on the running workflow**

3. **Expand job steps** to see detailed logs

4. **Watch for checkmarks** (✅) as each stage completes

### Check Workflow Status

```bash
# List recent runs
gh run list --workflow=full-deployment.yml

# Watch current run
gh run watch

# View specific run
gh run view <run-id> --log
```

### Monitor Azure Resources

While workflow is running:

```bash
# List all resources being created
az resource list \
  --resource-group <resource-group-name> \
  --output table

# Monitor specific resource
az functionapp show \
  --name <function-app-name> \
  --resource-group <resource-group-name> \
  --query "state"
```

## Downloading Deployment Details

After the workflow completes successfully:

### Via GitHub Web Interface

1. **Go to the completed workflow run**
2. **Scroll to "Artifacts" section** (bottom of page)
3. **Download** `deployment-details` artifact
4. **Extract the ZIP file**

The artifact contains:
- `deployment-details.txt` - Human-readable details
- `deployment-details.json` - Machine-readable JSON
- `DEPLOYMENT-INFO.md` - Markdown documentation
- `deployment-summary.md` - Quick reference
- `api-credentials.txt` - API keys (sensitive!)

### Via GitHub CLI

```bash
# List artifacts for latest run
gh run list --workflow=full-deployment.yml --limit 1

# Download artifacts
gh run download <run-id>

# Or download latest
gh run download $(gh run list --workflow=full-deployment.yml --limit 1 --json databaseId --jq '.[0].databaseId')
```

## Viewing Deployment Information

### In Workflow Summary

After the workflow completes, the summary page shows:

- 📋 **Resource Details**: Names and URLs
- 🌐 **API Endpoints**: All available endpoints
- 🔐 **Authentication**: Key Vault location
- 🤖 **Available Models**: Model specifications
- 📝 **Quick Start Examples**: cURL and Python
- 🎯 **Next Steps**: What to do after deployment

### In Downloaded Artifacts

**deployment-summary.md** - Quick overview with:
- Resource URLs
- API endpoints
- Authentication details
- Usage examples

**DEPLOYMENT-INFO.md** - Complete guide with:
- Full resource list
- Endpoint reference
- Model specifications
- Usage examples (cURL, Python, JavaScript)
- Troubleshooting commands
- Cost information

**deployment-details.json** - Structured data for automation:
```json
{
  "resource_group": {...},
  "endpoints": {...},
  "authentication": {...},
  "models": [...],
  "resources": {...}
}
```

**api-credentials.txt** - Sensitive credentials:
```
API_KEY=sk-...
```
⚠️ **Keep this file secure!** Do not commit to git.

## Using Deployment Information

### 1. Access the Frontend

```bash
# From deployment-details.txt
FRONTEND_URL="<url-from-artifact>"
open $FRONTEND_URL  # macOS
xdg-open $FRONTEND_URL  # Linux
start $FRONTEND_URL  # Windows
```

### 2. Test the API

```bash
# Get credentials from artifact
API_BASE_URL="<url-from-artifact>"
API_KEY="<key-from-artifact>"

# Test health endpoint
curl "${API_BASE_URL}/health/live"

# Test chat completion
curl -X POST "${API_BASE_URL}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d '{
    "model": "mixtral-8x7b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }'
```

### 3. Integrate with Your Application

**Python:**
```python
from openai import OpenAI

# Values from deployment artifact
client = OpenAI(
    api_key="<api-key-from-artifact>",
    base_url="<api-base-url-from-artifact>"
)

response = client.chat.completions.create(
    model="mixtral-8x7b",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

**JavaScript:**
```javascript
import OpenAI from 'openai';

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,  // From artifact
  baseURL: process.env.OPENAI_API_BASE_URL  // From artifact
});
```

## Troubleshooting

### Workflow Fails at Validation

**Issue:** Terraform validation errors

**Solution:**
- Check Terraform configuration in `terraform/` directory
- Run locally: `cd terraform && terraform validate`
- Fix any reported issues

### Workflow Fails at Infrastructure Deployment

**Issue:** Azure resource creation errors

**Common causes:**
1. **Insufficient permissions**: Ensure service principal has Contributor role
2. **Quota limits**: Check GPU quota in your subscription
3. **Name conflicts**: Resource names must be globally unique
4. **Region availability**: Some services not available in all regions

**Solution:**
```bash
# Check quota
az vm list-usage --location eastus \
  --query "[?name.value=='standardNCASv3Family']"

# Check available regions for Container Apps
az provider show \
  --namespace Microsoft.App \
  --query "resourceTypes[?resourceType=='containerApps'].locations"
```

### Workflow Fails at Function Deployment

**Issue:** Function app deployment errors

**Solution:**
- Verify Function App was created successfully
- Check if publish profile secret is configured
- Review function app logs:
  ```bash
  az functionapp log tail \
    --name <function-app-name> \
    --resource-group <resource-group-name>
  ```

### Workflow Fails at Frontend Deployment

**Issue:** Docker build or push fails

**Solution:**
- Check Dockerfile in `frontend/` directory
- Verify Container Registry credentials
- Check Docker daemon is running (in GitHub Actions, this should always work)

### No Artifacts Generated

**Issue:** Workflow completes but no artifacts

**Solution:**
- Ensure at least Stage 5 (Deployment Details) ran
- Check workflow permissions include artifact uploads
- Try re-running the workflow

### API Key Not in Artifacts

**Issue:** `api-credentials.txt` missing or empty

**Solution:**
```bash
# Manually retrieve from Key Vault
KEY_VAULT_NAME="<from-azure-portal-or-terraform-output>"

az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name frontend-openai-api-key \
  --query value -o tsv
```

## Re-running the Workflow

### Full Redeployment

To deploy everything again:

1. Trigger workflow with all options enabled
2. Wait for completion (25-35 minutes)
3. Download new artifacts

### Partial Redeployment

To redeploy only specific components:

**Infrastructure only:**
```bash
gh workflow run full-deployment.yml \
  -f deploy_infrastructure=true \
  -f deploy_functions=false \
  -f deploy_frontend=false
```

**Functions only:**
```bash
gh workflow run full-deployment.yml \
  -f deploy_infrastructure=false \
  -f deploy_functions=true \
  -f deploy_frontend=false
```

**Frontend only:**
```bash
gh workflow run full-deployment.yml \
  -f deploy_infrastructure=false \
  -f deploy_functions=false \
  -f deploy_frontend=true
```

## Cost Considerations

Running the workflow deploys Azure resources that incur costs:

| Phase | Estimated Cost |
|-------|---------------|
| Initial deployment | ~$0 (most resources scale to zero) |
| Idle state | ~$5/month |
| Active usage (10 GPU instances) | ~$1,100/month |

**Cost optimization tips:**
1. Scale down VMSS when not in use
2. Use consumption-based services (Functions, APIM)
3. Enable autoscaling with appropriate thresholds
4. Monitor costs in Azure Portal

## Next Steps

After successful deployment:

1. ✅ **Review deployment artifacts**
2. ✅ **Access frontend URL and create admin account**
3. ✅ **Test API endpoints with provided examples**
4. ✅ **Run `./setup-frontend-auth.sh` to secure frontend**
5. ✅ **Set up monitoring and alerts in Azure Portal**
6. ✅ **Review DEPLOYMENT-GUIDE.md for detailed usage**
7. ✅ **Configure CI/CD for automatic deployments**

## Support

For issues or questions:

1. Check workflow logs for detailed error messages
2. Review DEPLOYMENT-GUIDE.md for troubleshooting
3. Check Azure Portal for resource status
4. Review GitHub Issues for similar problems

## Related Documentation

- **DEPLOYMENT-GUIDE.md** - Complete deployment reference
- **README.md** - Project overview
- **PRODUCTION-README.md** - Production deployment guide
- **docs/frontend-deployment.md** - Frontend-specific guide
- **openapi.json** - API specification

---

**Ready to deploy?** Follow the Quick Start section above! 🚀
