# VSCode Configuration for Azure AI Inference Platform

## Quick Setup

### 1. Get Your API Credentials

```bash
# Get APIM endpoint
cd ../terraform
terraform output apim_gateway_url

# Get APIM name (to replace in settings.json.example)
terraform output apim_name
```

### 2. Configure VSCode

**Option A: User Settings (Recommended)**

1. Copy content from `settings.json.example`
2. Open VSCode: `Ctrl+,` (or `Cmd+,` on Mac)
3. Click "Open Settings (JSON)" icon
4. Paste configuration
5. Replace `YOUR-APIM-NAME` with actual APIM name

**Option B: Workspace Settings**

```bash
# Copy example to actual workspace settings
cp settings.json.example settings.json
# Edit and replace YOUR-APIM-NAME
nano settings.json
```

### 3. Set API Key

```bash
# Linux/Mac
export AZURE_AI_API_KEY="your-subscription-key-here"

# Windows PowerShell
$env:AZURE_AI_API_KEY="your-subscription-key-here"

# Or add to ~/.bashrc or ~/.zshrc for persistence
echo 'export AZURE_AI_API_KEY="your-key"' >> ~/.bashrc
```

### 4. Get API Key from Azure

**Via Azure Portal:**
1. Go to Azure Portal
2. Navigate to your API Management service
3. Click "Subscriptions" in left menu
4. Copy primary or secondary key

**Via Azure CLI:**
```bash
APIM_NAME=$(terraform output -raw apim_name)
RG_NAME=$(terraform output -raw resource_group_name)

az apim subscription list \
  --resource-group $RG_NAME \
  --service-name $APIM_NAME \
  --query "[].{name:name, primaryKey:primaryKey}" \
  -o table
```

## Available Models

| Model ID | Name | Context | Cost/1K | Best For |
|----------|------|---------|---------|----------|
| `mixtral-8x7b` | Mixtral 8x7B | 32K | $0.002 | Complex reasoning, long docs |
| `llama-3-70b` | Llama 3 70B | 8K | $0.003 | Balanced tasks |
| `phi-3-mini` | Phi-3 Mini | 4K | $0.0005 | Simple/fast tasks |
| `auto` | Auto-select | - | Variable | Automatic selection |

## Testing

```bash
# Test health endpoint
curl $(terraform output -raw apim_gateway_url)/inference/health

# Test with API key
curl $(terraform output -raw apim_gateway_url)/inference/models \
  -H "Ocp-Apim-Subscription-Key: $AZURE_AI_API_KEY"
```

## Troubleshooting

### Connection Fails
- Verify APIM name in `baseURL`
- Check environment variable: `echo $AZURE_AI_API_KEY`
- Test endpoint with curl (see above)

### 401 Unauthorized
- Verify header name: `Ocp-Apim-Subscription-Key`
- Check key hasn't expired
- Regenerate key in Azure Portal if needed

### Rate Limit (429)
- Default: 1000 requests/minute
- Adjust `kilocode.rateLimits.requestsPerMinute` to 900

## Documentation

- [KILOCODE_INTEGRATION.md](../KILOCODE_INTEGRATION.md) - Complete setup guide
- [docs/kilocode-quickstart.md](../docs/kilocode-quickstart.md) - Quick reference
- [terraform/README.md](../terraform/README.md) - Infrastructure deployment
