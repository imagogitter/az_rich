# Quick Start: Kilocode VSCode Extension Integration

## 1. Get Your API Credentials

```bash
cd terraform
terraform output apim_gateway_url
# Output: https://ai-inference-apim.azure-api.net
```

Get subscription key from Azure Portal → API Management → Subscriptions

## 2. Configure VSCode Settings

Add to `.vscode/settings.json` or user settings:

```json
{
  "kilocode.customProviders": [
    {
      "name": "Azure AI Inference",
      "type": "openai-compatible",
      "baseURL": "https://YOUR-APIM-NAME.azure-api.net/inference",
      "apiKey": "${env:AZURE_AI_API_KEY}",
      "headers": {
        "Ocp-Apim-Subscription-Key": "${env:AZURE_AI_API_KEY}"
      },
      "models": [
        {"id": "mixtral-8x7b", "name": "Mixtral 8x7B", "contextLength": 32768},
        {"id": "llama-3-70b", "name": "Llama 3 70B", "contextLength": 8192},
        {"id": "phi-3-mini", "name": "Phi-3 Mini", "contextLength": 4096},
        {"id": "auto", "name": "Auto-select"}
      ]
    }
  ],
  "kilocode.defaultProvider": "Azure AI Inference",
  "kilocode.defaultModel": "auto"
}
```

## 3. Set Environment Variable

```bash
# Linux/Mac
export AZURE_AI_API_KEY="your-subscription-key-here"

# Windows PowerShell
$env:AZURE_AI_API_KEY="your-subscription-key-here"

# Windows CMD
set AZURE_AI_API_KEY=your-subscription-key-here
```

## 4. Test Connection

```bash
# Test health
curl https://YOUR-APIM-NAME.azure-api.net/inference/health

# Test with key
curl https://YOUR-APIM-NAME.azure-api.net/inference/models \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY"
```

## 5. Start Using

In VSCode:
- Type code comment + Tab → Auto-completion
- Select code → Right-click → "Kilocode: Explain"
- `Ctrl+Shift+P` → "Kilocode: Custom Prompt"

## Available Models

| Model | Best For | Context | Cost/1K tokens |
|-------|----------|---------|----------------|
| **mixtral-8x7b** | Complex reasoning, long docs | 32K | $0.002 |
| **llama-3-70b** | Balanced tasks | 8K | $0.003 |
| **phi-3-mini** | Simple/fast tasks | 4K | $0.0005 |
| **auto** | Automatic selection | - | Variable |

## Troubleshooting

**Connection fails:**
```bash
# Check endpoint
curl https://YOUR-APIM-NAME.azure-api.net/inference/health

# Verify key
az apim subscription list --service-name YOUR-APIM-NAME --resource-group YOUR-RG
```

**401 Unauthorized:**
- Check header: `Ocp-Apim-Subscription-Key`
- Verify key hasn't expired

**429 Rate Limit:**
- Default: 1000 req/min
- Set `kilocode.rateLimits.requestsPerMinute: 900`

See [KILOCODE_INTEGRATION.md](../KILOCODE_INTEGRATION.md) for full documentation.
