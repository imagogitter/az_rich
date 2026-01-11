# Integrating Azure AI Inference Platform with Kilocode VSCode Extension

This guide provides steps to wire the project's AI models into the Kilocode VSCode extension.

## Prerequisites

- VSCode with Kilocode extension installed
- Azure AI Inference Platform deployed (see [terraform/README.md](terraform/README.md))
- API Management endpoint URL
- API subscription key or bearer token

## Overview

The Azure AI Inference Platform provides OpenAI-compatible endpoints for three models:
- **Mixtral 8x7B** - Best for complex reasoning tasks (32K context)
- **Llama-3-70B** - Balanced performance and cost (8K context)
- **Phi-3-mini** - Fastest and cheapest option (4K context)

## Step 1: Obtain Your API Credentials

### Get API Endpoint

From your Terraform deployment:

```bash
cd terraform
terraform output apim_gateway_url
# Output example: https://ai-inference-apim.azure-api.net
```

Your API base URL will be:
```
https://ai-inference-apim.azure-api.net/inference
```

### Get API Key

Option A - From Azure Portal:
1. Navigate to your API Management instance
2. Go to **Subscriptions**
3. Copy the primary or secondary key

Option B - From Terraform:
```bash
# Get APIM name
APIM_NAME=$(terraform output -raw apim_name)
RG_NAME=$(terraform output -raw resource_group_name)

# List subscriptions
az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RG_NAME/providers/Microsoft.ApiManagement/service/$APIM_NAME/subscriptions?api-version=2022-08-01"
```

## Step 2: Configure Kilocode Extension

### Open VSCode Settings

1. Open VSCode
2. Press `Ctrl+,` (Windows/Linux) or `Cmd+,` (Mac)
3. Search for "Kilocode"

### Configure Custom API Provider

Add the following configuration to your VSCode `settings.json`:

```json
{
  "kilocode.customProviders": [
    {
      "name": "Azure AI Inference",
      "type": "openai-compatible",
      "baseURL": "https://ai-inference-apim.azure-api.net/inference",
      "apiKey": "YOUR_APIM_SUBSCRIPTION_KEY",
      "models": [
        {
          "id": "mixtral-8x7b",
          "name": "Mixtral 8x7B",
          "contextLength": 32768,
          "description": "Best for complex reasoning and long context"
        },
        {
          "id": "llama-3-70b",
          "name": "Llama 3 70B",
          "contextLength": 8192,
          "description": "Balanced performance and cost"
        },
        {
          "id": "phi-3-mini",
          "name": "Phi-3 Mini",
          "contextLength": 4096,
          "description": "Fastest and most cost-effective"
        }
      ]
    }
  ]
}
```

## Step 3: Configure API Authentication

The platform uses API Management authentication. Choose one method:

### Method A: Subscription Key (Recommended)

Add to request headers:
```json
{
  "kilocode.customProviders[0].headers": {
    "Ocp-Apim-Subscription-Key": "YOUR_SUBSCRIPTION_KEY"
  }
}
```

### Method B: Bearer Token

If using Azure AD authentication:
```json
{
  "kilocode.customProviders[0].headers": {
    "Authorization": "Bearer YOUR_AZURE_AD_TOKEN"
  }
}
```

## Step 4: Configure Model Selection

### Automatic Model Selection

The platform supports automatic model selection based on prompt complexity:

```json
{
  "kilocode.defaultModel": "auto",
  "kilocode.autoModelSelection": true
}
```

When `model: "auto"` is used, the platform automatically routes to:
- **phi-3-mini**: Prompts < 1000 tokens
- **llama-3-70b**: Prompts 1000-4000 tokens
- **mixtral-8x7b**: Prompts > 4000 tokens or complex reasoning

### Manual Model Selection

Set a specific default model:

```json
{
  "kilocode.defaultModel": "mixtral-8x7b"
}
```

## Step 5: Configure Advanced Settings

### Enable Caching (40% hit rate)

Caching is enabled by default on the backend. To leverage it:

```json
{
  "kilocode.customProviders[0].caching": {
    "enabled": true,
    "ttl": 86400  // 24 hours (matches backend)
  }
}
```

### Set Rate Limits

The API Management layer enforces 1000 requests per minute:

```json
{
  "kilocode.rateLimits": {
    "requestsPerMinute": 1000,
    "tokensPerMinute": 100000
  }
}
```

### Configure Timeout

```json
{
  "kilocode.customProviders[0].timeout": 30000  // 30 seconds
}
```

## Step 6: Test the Connection

### Test via VSCode Command Palette

1. Press `Ctrl+Shift+P` (Windows/Linux) or `Cmd+Shift+P` (Mac)
2. Type "Kilocode: Test Connection"
3. Select "Azure AI Inference"

### Test via curl

```bash
# Test health endpoint
curl https://ai-inference-apim.azure-api.net/inference/health

# Test models list
curl https://ai-inference-apim.azure-api.net/inference/models \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY"

# Test chat completion
curl https://ai-inference-apim.azure-api.net/inference/chat/completions \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  -d '{
    "model": "phi-3-mini",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }'
```

## Step 7: Workspace Configuration (Optional)

For team collaboration, add to `.vscode/settings.json` in your workspace:

```json
{
  "kilocode.customProviders": [
    {
      "name": "Azure AI Inference",
      "type": "openai-compatible",
      "baseURL": "https://ai-inference-apim.azure-api.net/inference",
      "apiKey": "${env:AZURE_AI_API_KEY}",
      "models": [
        {"id": "mixtral-8x7b", "name": "Mixtral 8x7B"},
        {"id": "llama-3-70b", "name": "Llama 3 70B"},
        {"id": "phi-3-mini", "name": "Phi-3 Mini"}
      ],
      "headers": {
        "Ocp-Apim-Subscription-Key": "${env:AZURE_AI_API_KEY}"
      }
    }
  ]
}
```

Then set environment variable:
```bash
export AZURE_AI_API_KEY="your-subscription-key"
```

## Complete Configuration Example

Here's a complete `settings.json` configuration:

```json
{
  // Azure AI Inference Platform Configuration
  "kilocode.customProviders": [
    {
      "name": "Azure AI Inference",
      "type": "openai-compatible",
      "enabled": true,
      "baseURL": "https://ai-inference-apim.azure-api.net/inference",
      "apiKey": "${env:AZURE_AI_API_KEY}",
      
      // Headers for APIM authentication
      "headers": {
        "Ocp-Apim-Subscription-Key": "${env:AZURE_AI_API_KEY}",
        "X-Client-Name": "kilocode-vscode"
      },
      
      // Available models
      "models": [
        {
          "id": "mixtral-8x7b",
          "name": "Mixtral 8x7B",
          "contextLength": 32768,
          "pricing": {
            "prompt": 0.002,
            "completion": 0.002
          },
          "description": "Best for complex reasoning, long documents, and multi-step tasks"
        },
        {
          "id": "llama-3-70b",
          "name": "Llama 3 70B",
          "contextLength": 8192,
          "pricing": {
            "prompt": 0.003,
            "completion": 0.003
          },
          "description": "Balanced option for most coding tasks"
        },
        {
          "id": "phi-3-mini",
          "name": "Phi-3 Mini",
          "contextLength": 4096,
          "pricing": {
            "prompt": 0.0005,
            "completion": 0.0005
          },
          "description": "Fastest and most cost-effective for simple tasks"
        },
        {
          "id": "auto",
          "name": "Auto-select",
          "description": "Automatically choose the best model based on prompt"
        }
      ],
      
      // Performance settings
      "timeout": 30000,
      "retries": 3,
      "retryDelay": 1000,
      
      // Caching (backend handles this)
      "caching": {
        "enabled": true,
        "ttl": 86400
      }
    }
  ],
  
  // Default settings
  "kilocode.defaultProvider": "Azure AI Inference",
  "kilocode.defaultModel": "auto",
  
  // Rate limiting
  "kilocode.rateLimits": {
    "requestsPerMinute": 900,  // Slightly under APIM limit
    "tokensPerMinute": 100000
  }
}
```

## Usage Examples

### Code Completion

```typescript
// Kilocode will automatically use your configured provider
// Type a comment and press Tab to trigger completion
// Example: Write a function to sort an array
```

### Code Explanation

Select code, right-click, and choose "Kilocode: Explain Code"

### Refactoring

Select code, right-click, and choose "Kilocode: Refactor"

### Custom Prompts

Use the Kilocode command palette to send custom prompts:
1. `Ctrl+Shift+P` → "Kilocode: Custom Prompt"
2. Enter your prompt
3. Choose model: "Azure AI Inference - Auto-select"

## Monitoring and Cost Tracking

### View API Usage

Check Application Insights:
```bash
az monitor app-insights query \
  --app $(terraform output -raw application_insights_name) \
  --analytics-query "
    requests
    | where cloud_RoleName == 'api-orchestrator'
    | summarize requests=count(), avg_duration=avg(duration) by bin(timestamp, 1h)
  "
```

### Track Costs

```bash
# View Cosmos DB cache stats
az cosmosdb sql container show \
  --account-name $(terraform output -raw cosmos_account_name) \
  --database-name inference-cache \
  --name responses \
  --resource-group $(terraform output -raw resource_group_name) \
  --query "{requests: statistics.requests, cacheHitRate: statistics.cacheHitRate}"

# View VMSS scaling events
az monitor metrics list \
  --resource $(terraform output -raw vmss_name) \
  --metric "Percentage CPU"
```

## Troubleshooting

### Connection Issues

1. **Verify API endpoint:**
   ```bash
   curl https://ai-inference-apim.azure-api.net/inference/health
   ```

2. **Check subscription key:**
   ```bash
   az apim subscription list \
     --resource-group $(terraform output -raw resource_group_name) \
     --service-name $(terraform output -raw apim_name)
   ```

3. **Verify CORS settings:**
   - CORS is configured in Function App to allow all origins by default
   - For production, restrict via `allowed_cors_origins` in terraform.tfvars

### Authentication Errors

If you get 401 Unauthorized:
- Verify subscription key is correct
- Check key hasn't expired
- Ensure header name is `Ocp-Apim-Subscription-Key`

### Rate Limit Errors

If you get 429 Too Many Requests:
- Default limit: 1000 requests/60 seconds
- Adjust `kilocode.rateLimits.requestsPerMinute` to 900
- Consider implementing exponential backoff

### Model Not Found Errors

If you get "model not found":
- Verify model ID matches exactly: `mixtral-8x7b`, `llama-3-70b`, or `phi-3-mini`
- Check API endpoint includes `/inference` path
- Test with curl to verify backend is running

## Advanced Configuration

### Multi-Environment Setup

```json
{
  "kilocode.customProviders": [
    {
      "name": "Azure AI Inference (Dev)",
      "baseURL": "https://ai-inference-dev-apim.azure-api.net/inference",
      "apiKey": "${env:AZURE_AI_API_KEY_DEV}"
    },
    {
      "name": "Azure AI Inference (Prod)",
      "baseURL": "https://ai-inference-prod-apim.azure-api.net/inference",
      "apiKey": "${env:AZURE_AI_API_KEY_PROD}"
    }
  ]
}
```

### Custom Model Routing

Override automatic model selection:

```json
{
  "kilocode.modelSelectionRules": [
    {
      "condition": "fileType == 'typescript'",
      "model": "llama-3-70b"
    },
    {
      "condition": "promptLength < 500",
      "model": "phi-3-mini"
    },
    {
      "condition": "requiresReasoning",
      "model": "mixtral-8x7b"
    }
  ]
}
```

### Logging

Enable request/response logging:

```json
{
  "kilocode.logging": {
    "enabled": true,
    "level": "debug",
    "logRequests": true,
    "logResponses": false  // Don't log to avoid leaking code
  }
}
```

## Resources

- [OpenAPI Specification](openapi.json) - Full API documentation
- [Deployment Guide](terraform/README.md) - Infrastructure setup
- [API Usage Guide](ai-inference-demo/docs/api-usage.md) - API examples
- [Congruency Report](CONGRUENCY_REPORT.md) - Architecture verification

## Security Notes

- **Never commit API keys** to version control
- Use environment variables: `${env:AZURE_AI_API_KEY}`
- Rotate keys regularly via Azure Portal
- Restrict CORS origins in production (set `allowed_cors_origins` in terraform.tfvars)
- Use Azure Key Vault for key storage in CI/CD
- Monitor unusual usage patterns via Application Insights

## Cost Optimization Tips

1. **Use auto model selection** to automatically route to cheapest appropriate model
2. **Enable caching** - 40% hit rate reduces costs significantly
3. **Set appropriate context lengths** - Smaller contexts are cheaper
4. **Use phi-3-mini** for simple tasks (5x cheaper than mixtral-8x7b)
5. **Monitor via Application Insights** to identify optimization opportunities
6. **Scale VMSS to 0 during idle** - saves ~$1,080/month when not in use

## Support

For issues or questions:
- Infrastructure: See [terraform/README.md](terraform/README.md)
- API Usage: See [openapi.json](openapi.json)
- Architecture: See [CONGRUENCY_REPORT.md](CONGRUENCY_REPORT.md)
- Deployment: See [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md)
