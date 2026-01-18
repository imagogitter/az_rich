#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# GET DEPLOYMENT DETAILS SCRIPT
# =============================================================================
# This script retrieves comprehensive deployment information for the
# AI Inference Arbitrage Platform including endpoints, API keys, model options,
# and connection details for all Azure resources.
#
# Prerequisites:
#   - Azure CLI installed and logged in (az login)
#   - Terraform infrastructure deployed
#   - Appropriate permissions to read Key Vault secrets
#
# Usage:
#   ./scripts/get-deployment-details.sh
#   ./scripts/get-deployment-details.sh --json > deployment-info.json
#   ./scripts/get-deployment-details.sh --markdown > DEPLOYMENT-INFO.md
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
header() { echo -e "${BLUE}===========================================================${NC}"; echo -e "${BLUE}$*${NC}"; echo -e "${BLUE}===========================================================${NC}"; }

# Check prerequisites
check_prereqs() {
  command -v az >/dev/null 2>&1 || { error "Azure CLI not found. Install from: https://learn.microsoft.com/cli/azure/install-azure-cli"; exit 1; }
  
  # Check if logged in to Azure
  if ! az account show >/dev/null 2>&1; then
    error "Not logged in to Azure. Run 'az login' first."
    exit 1
  fi
}

# Get Terraform outputs
get_terraform_outputs() {
  if [ ! -d "terraform" ]; then
    error "terraform directory not found. Run from project root."
    exit 1
  fi
  
  cd terraform || exit 1
  
  # Check if terraform state exists
  if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
    warn "Terraform state not found. Infrastructure may not be deployed yet."
    cd ..
    return 1
  fi
  
  RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
  KEY_VAULT_NAME=$(terraform output -raw key_vault_name 2>/dev/null || echo "")
  COSMOS_ACCOUNT_NAME=$(terraform output -raw cosmos_account_name 2>/dev/null || echo "")
  STORAGE_ACCOUNT_NAME=$(terraform output -raw storage_account_name 2>/dev/null || echo "")
  FUNCTION_APP_NAME=$(terraform output -raw function_app_name 2>/dev/null || echo "")
  APIM_NAME=$(terraform output -raw apim_name 2>/dev/null || echo "")
  VMSS_NAME=$(terraform output -raw vmss_name 2>/dev/null || echo "")
  FRONTEND_URL=$(terraform output -raw frontend_url 2>/dev/null || echo "")
  FRONTEND_APP_NAME=$(terraform output -raw frontend_app_name 2>/dev/null || echo "")
  CONTAINER_REGISTRY_NAME=$(terraform output -raw container_registry_name 2>/dev/null || echo "")
  CONTAINER_REGISTRY_LOGIN_SERVER=$(terraform output -raw container_registry_login_server 2>/dev/null || echo "")
  
  cd ..
}

# Get API endpoints
get_api_endpoints() {
  if [ -n "$FUNCTION_APP_NAME" ]; then
    FUNCTION_APP_URL="https://${FUNCTION_APP_NAME}.azurewebsites.net"
    API_BASE_URL="${FUNCTION_APP_URL}/api"
  else
    FUNCTION_APP_URL=""
    API_BASE_URL=""
  fi
  
  if [ -n "$APIM_NAME" ]; then
    APIM_GATEWAY_URL="https://${APIM_NAME}.azure-api.net"
  else
    APIM_GATEWAY_URL=""
  fi
}

# Get API keys from Key Vault
get_api_keys() {
  if [ -z "$KEY_VAULT_NAME" ]; then
    warn "Key Vault name not found"
    FRONTEND_API_KEY=""
    INFERENCE_API_KEY=""
    return
  fi
  
  # Get frontend API key
  FRONTEND_API_KEY=$(az keyvault secret show \
    --vault-name "$KEY_VAULT_NAME" \
    --name "frontend-openai-api-key" \
    --query "value" -o tsv 2>/dev/null || echo "")
  
  # Get inference API key
  INFERENCE_API_KEY=$(az keyvault secret show \
    --vault-name "$KEY_VAULT_NAME" \
    --name "inference-api-key" \
    --query "value" -o tsv 2>/dev/null || echo "")
  
  # If specific keys not found, list available secrets
  if [ -z "$FRONTEND_API_KEY" ] && [ -z "$INFERENCE_API_KEY" ]; then
    warn "No API keys found in Key Vault. Available secrets:"
    az keyvault secret list --vault-name "$KEY_VAULT_NAME" --query "[].name" -o tsv 2>/dev/null || true
  fi
}

# Get resource status
get_resource_status() {
  if [ -z "$RESOURCE_GROUP" ]; then
    warn "Resource group not found"
    return
  fi
  
  log "Checking resource deployment status..."
  
  # Check Function App
  if [ -n "$FUNCTION_APP_NAME" ]; then
    FUNCTION_STATUS=$(az functionapp show \
      --name "$FUNCTION_APP_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --query "state" -o tsv 2>/dev/null || echo "Not Found")
  else
    FUNCTION_STATUS="Not Configured"
  fi
  
  # Check APIM
  if [ -n "$APIM_NAME" ]; then
    APIM_STATUS=$(az apim show \
      --name "$APIM_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --query "provisioningState" -o tsv 2>/dev/null || echo "Not Found")
  else
    APIM_STATUS="Not Configured"
  fi
  
  # Check VMSS
  if [ -n "$VMSS_NAME" ]; then
    VMSS_INSTANCES=$(az vmss show \
      --name "$VMSS_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --query "sku.capacity" -o tsv 2>/dev/null || echo "0")
    VMSS_STATUS="Running (${VMSS_INSTANCES} instances)"
  else
    VMSS_STATUS="Not Configured"
    VMSS_INSTANCES="0"
  fi
  
  # Check Frontend
  if [ -n "$FRONTEND_APP_NAME" ]; then
    FRONTEND_STATUS=$(az containerapp show \
      --name "$FRONTEND_APP_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --query "properties.runningStatus" -o tsv 2>/dev/null || echo "Not Found")
  else
    FRONTEND_STATUS="Not Configured"
  fi
}

# Get model information
get_model_info() {
  # Available models based on platform architecture
  MODELS=(
    "llama-3-70b|High-quality responses|8K context|Standard_NC4as_T4_v3"
    "mixtral-8x7b|Fast and efficient|32K context|Standard_NC4as_T4_v3"
    "phi-3-mini|Lightweight model|4K context|Standard_NC4as_T4_v3"
  )
}

# Display deployment details (human-readable format)
display_deployment_details() {
  header "AI INFERENCE PLATFORM - DEPLOYMENT DETAILS"
  echo ""
  
  echo "📋 RESOURCE GROUP INFORMATION"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Resource Group:    ${RESOURCE_GROUP:-Not Available}"
  echo "Location:          $(az group show --name "$RESOURCE_GROUP" --query "location" -o tsv 2>/dev/null || echo "N/A")"
  echo ""
  
  echo "🌐 API ENDPOINTS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Function App URL:       ${FUNCTION_APP_URL:-Not Available}"
  echo "API Base URL:           ${API_BASE_URL:-Not Available}"
  echo "APIM Gateway URL:       ${APIM_GATEWAY_URL:-Not Available}"
  echo "Frontend URL:           ${FRONTEND_URL:-Not Available}"
  echo ""
  echo "📍 Specific Endpoints:"
  if [ -n "$API_BASE_URL" ]; then
    echo "  • Chat Completions:   ${API_BASE_URL}/v1/chat/completions"
    echo "  • List Models:        ${API_BASE_URL}/v1/models"
    echo "  • Health (Live):      ${API_BASE_URL}/health/live"
    echo "  • Health (Ready):     ${API_BASE_URL}/health/ready"
  else
    echo "  API endpoints not available - infrastructure not deployed"
  fi
  echo ""
  
  echo "🔐 API KEYS & AUTHENTICATION"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Key Vault Name:         ${KEY_VAULT_NAME:-Not Available}"
  if [ -n "$FRONTEND_API_KEY" ]; then
    # Mask the API key in output (show only first 8 chars)
    echo "Frontend API Key:       ${FRONTEND_API_KEY:0:8}... (stored in Key Vault)"
  else
    echo "Frontend API Key:       Not Available (check Key Vault: frontend-openai-api-key)"
  fi
  if [ -n "$INFERENCE_API_KEY" ]; then
    # Mask the API key in output (show only first 8 chars)
    echo "Inference API Key:      ${INFERENCE_API_KEY:0:8}... (stored in Key Vault)"
  else
    echo "Inference API Key:      Not Available (check Key Vault: inference-api-key)"
  fi
  echo ""
  echo "To retrieve API keys:"
  if [ -n "$KEY_VAULT_NAME" ]; then
    echo "  az keyvault secret show --vault-name $KEY_VAULT_NAME --name frontend-openai-api-key --query value -o tsv"
    echo "  az keyvault secret show --vault-name $KEY_VAULT_NAME --name inference-api-key --query value -o tsv"
  fi
  echo ""
  
  echo "🤖 AVAILABLE MODELS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "%-20s %-25s %-15s %s\n" "Model ID" "Description" "Context" "VM SKU"
  echo "────────────────────────────────────────────────────────────"
  for model in "${MODELS[@]}"; do
    IFS='|' read -r id desc context sku <<< "$model"
    printf "%-20s %-25s %-15s %s\n" "$id" "$desc" "$context" "$sku"
  done
  echo ""
  echo "Model Selection:"
  echo "  • Use 'auto' to automatically select based on context length"
  echo "  • Specify model ID for explicit selection"
  echo ""
  
  echo "🎯 RESOURCE STATUS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "%-25s %s\n" "Function App:" "$FUNCTION_STATUS"
  printf "%-25s %s\n" "API Management:" "$APIM_STATUS"
  printf "%-25s %s\n" "VM Scale Set:" "$VMSS_STATUS"
  printf "%-25s %s\n" "Frontend:" "$FRONTEND_STATUS"
  echo ""
  
  echo "💾 AZURE RESOURCES"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Function App:           ${FUNCTION_APP_NAME:-Not Available}"
  echo "APIM:                   ${APIM_NAME:-Not Available}"
  echo "VMSS:                   ${VMSS_NAME:-Not Available}"
  echo "Cosmos DB:              ${COSMOS_ACCOUNT_NAME:-Not Available}"
  echo "Storage Account:        ${STORAGE_ACCOUNT_NAME:-Not Available}"
  echo "Container Registry:     ${CONTAINER_REGISTRY_NAME:-Not Available}"
  echo "Frontend App:           ${FRONTEND_APP_NAME:-Not Available}"
  echo ""
  
  echo "📊 USAGE EXAMPLE (cURL)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [ -n "$API_BASE_URL" ] && [ -n "$FRONTEND_API_KEY" ]; then
    cat <<'EOF'
curl -X POST "${API_BASE_URL}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d '{
    "model": "mixtral-8x7b",
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ],
    "max_tokens": 256,
    "temperature": 0.7
  }'
EOF
  else
    echo "API endpoint or key not available. Deploy infrastructure first."
  fi
  echo ""
  
  echo "🐍 USAGE EXAMPLE (Python)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [ -n "$API_BASE_URL" ]; then
    cat <<EOF
from openai import OpenAI

client = OpenAI(
    api_key="${FRONTEND_API_KEY:0:20}...",  # Get from Key Vault
    base_url="${API_BASE_URL}/v1"
)

response = client.chat.completions.create(
    model="mixtral-8x7b",
    messages=[
        {"role": "user", "content": "Hello, how are you?"}
    ],
    max_tokens=256,
    temperature=0.7
)

print(response.choices[0].message.content)
EOF
  else
    echo "API endpoint not available. Deploy infrastructure first."
  fi
  echo ""
  
  echo "🛠️  USEFUL COMMANDS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [ -n "$FUNCTION_APP_NAME" ] && [ -n "$RESOURCE_GROUP" ]; then
    echo "View Function App logs:"
    echo "  az functionapp log tail --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP"
    echo ""
  fi
  if [ -n "$FRONTEND_APP_NAME" ] && [ -n "$RESOURCE_GROUP" ]; then
    echo "View Frontend logs:"
    echo "  az containerapp logs show --name $FRONTEND_APP_NAME --resource-group $RESOURCE_GROUP --tail 50"
    echo ""
  fi
  if [ -n "$VMSS_NAME" ] && [ -n "$RESOURCE_GROUP" ]; then
    echo "Scale VMSS manually:"
    echo "  az vmss scale --name $VMSS_NAME --resource-group $RESOURCE_GROUP --new-capacity 2"
    echo ""
  fi
  echo "Test health endpoint:"
  if [ -n "$API_BASE_URL" ]; then
    echo "  curl ${API_BASE_URL}/health/live"
  fi
  echo ""
  
  echo "📚 DOCUMENTATION"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "• OpenAPI Spec:         openapi.json"
  echo "• Frontend Guide:       docs/frontend-deployment.md"
  echo "• Production Guide:     PRODUCTION-README.md"
  echo "• Quick Start:          README.md"
  echo ""
  
  header "DEPLOYMENT DETAILS COMPLETE"
}

# Output as JSON
output_json() {
  cat <<EOF
{
  "resource_group": {
    "name": "${RESOURCE_GROUP:-null}",
    "location": "$(az group show --name "$RESOURCE_GROUP" --query "location" -o tsv 2>/dev/null || echo "null")"
  },
  "endpoints": {
    "function_app_url": "${FUNCTION_APP_URL:-null}",
    "api_base_url": "${API_BASE_URL:-null}",
    "apim_gateway_url": "${APIM_GATEWAY_URL:-null}",
    "frontend_url": "${FRONTEND_URL:-null}",
    "chat_completions": "${API_BASE_URL}/v1/chat/completions",
    "models": "${API_BASE_URL}/v1/models",
    "health_live": "${API_BASE_URL}/health/live",
    "health_ready": "${API_BASE_URL}/health/ready"
  },
  "authentication": {
    "key_vault_name": "${KEY_VAULT_NAME:-null}",
    "frontend_api_key_secret": "frontend-openai-api-key",
    "inference_api_key_secret": "inference-api-key"
  },
  "models": [
    {
      "id": "llama-3-70b",
      "description": "High-quality responses",
      "context_length": "8K",
      "vm_sku": "Standard_NC4as_T4_v3"
    },
    {
      "id": "mixtral-8x7b",
      "description": "Fast and efficient",
      "context_length": "32K",
      "vm_sku": "Standard_NC4as_T4_v3"
    },
    {
      "id": "phi-3-mini",
      "description": "Lightweight model",
      "context_length": "4K",
      "vm_sku": "Standard_NC4as_T4_v3"
    }
  ],
  "resources": {
    "function_app_name": "${FUNCTION_APP_NAME:-null}",
    "function_status": "${FUNCTION_STATUS:-null}",
    "apim_name": "${APIM_NAME:-null}",
    "apim_status": "${APIM_STATUS:-null}",
    "vmss_name": "${VMSS_NAME:-null}",
    "vmss_instances": ${VMSS_INSTANCES:-0},
    "vmss_status": "${VMSS_STATUS:-null}",
    "cosmos_account": "${COSMOS_ACCOUNT_NAME:-null}",
    "storage_account": "${STORAGE_ACCOUNT_NAME:-null}",
    "container_registry": "${CONTAINER_REGISTRY_NAME:-null}",
    "frontend_app_name": "${FRONTEND_APP_NAME:-null}",
    "frontend_status": "${FRONTEND_STATUS:-null}"
  }
}
EOF
}

# Output as Markdown
output_markdown() {
  cat <<EOF
# AI Inference Platform - Deployment Information

**Generated:** $(date)

## Resource Group

- **Name:** ${RESOURCE_GROUP:-Not Available}
- **Location:** $(az group show --name "$RESOURCE_GROUP" --query "location" -o tsv 2>/dev/null || echo "N/A")

## API Endpoints

### Base URLs

- **Function App URL:** ${FUNCTION_APP_URL:-Not Available}
- **API Base URL:** ${API_BASE_URL:-Not Available}
- **APIM Gateway URL:** ${APIM_GATEWAY_URL:-Not Available}
- **Frontend URL:** ${FRONTEND_URL:-Not Available}

### Specific Endpoints

| Endpoint | URL |
|----------|-----|
| Chat Completions | \`${API_BASE_URL}/v1/chat/completions\` |
| List Models | \`${API_BASE_URL}/v1/models\` |
| Health (Live) | \`${API_BASE_URL}/health/live\` |
| Health (Ready) | \`${API_BASE_URL}/health/ready\` |

## Authentication

- **Key Vault Name:** ${KEY_VAULT_NAME:-Not Available}
- **Frontend API Key:** Stored in Key Vault as \`frontend-openai-api-key\`
- **Inference API Key:** Stored in Key Vault as \`inference-api-key\`

### Retrieve API Keys

\`\`\`bash
# Frontend API Key
az keyvault secret show --vault-name ${KEY_VAULT_NAME} --name frontend-openai-api-key --query value -o tsv

# Inference API Key
az keyvault secret show --vault-name ${KEY_VAULT_NAME} --name inference-api-key --query value -o tsv
\`\`\`

## Available Models

| Model ID | Description | Context Length | VM SKU |
|----------|-------------|----------------|--------|
| llama-3-70b | High-quality responses | 8K | Standard_NC4as_T4_v3 |
| mixtral-8x7b | Fast and efficient | 32K | Standard_NC4as_T4_v3 |
| phi-3-mini | Lightweight model | 4K | Standard_NC4as_T4_v3 |

## Resource Status

| Resource | Status |
|----------|--------|
| Function App | ${FUNCTION_STATUS} |
| API Management | ${APIM_STATUS} |
| VM Scale Set | ${VMSS_STATUS} |
| Frontend | ${FRONTEND_STATUS} |

## Azure Resources

- **Function App:** ${FUNCTION_APP_NAME:-Not Available}
- **API Management:** ${APIM_NAME:-Not Available}
- **VM Scale Set:** ${VMSS_NAME:-Not Available}
- **Cosmos DB:** ${COSMOS_ACCOUNT_NAME:-Not Available}
- **Storage Account:** ${STORAGE_ACCOUNT_NAME:-Not Available}
- **Container Registry:** ${CONTAINER_REGISTRY_NAME:-Not Available}
- **Frontend Container App:** ${FRONTEND_APP_NAME:-Not Available}

## Usage Examples

### cURL

\`\`\`bash
curl -X POST "${API_BASE_URL}/v1/chat/completions" \\
  -H "Content-Type: application/json" \\
  -H "Authorization: Bearer \${API_KEY}" \\
  -d '{
    "model": "mixtral-8x7b",
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ],
    "max_tokens": 256,
    "temperature": 0.7
  }'
\`\`\`

### Python (OpenAI SDK)

\`\`\`python
from openai import OpenAI

client = OpenAI(
    api_key="your-api-key",  # Get from Key Vault
    base_url="${API_BASE_URL}/v1"
)

response = client.chat.completions.create(
    model="mixtral-8x7b",
    messages=[
        {"role": "user", "content": "Hello, how are you?"}
    ],
    max_tokens=256,
    temperature=0.7
)

print(response.choices[0].message.content)
\`\`\`

## Useful Commands

### View Logs

\`\`\`bash
# Function App logs
az functionapp log tail --name ${FUNCTION_APP_NAME} --resource-group ${RESOURCE_GROUP}

# Frontend logs
az containerapp logs show --name ${FRONTEND_APP_NAME} --resource-group ${RESOURCE_GROUP} --tail 50
\`\`\`

### Scale Resources

\`\`\`bash
# Scale VMSS manually
az vmss scale --name ${VMSS_NAME} --resource-group ${RESOURCE_GROUP} --new-capacity 2
\`\`\`

### Test Health

\`\`\`bash
curl ${API_BASE_URL}/health/live
\`\`\`

## Documentation

- **OpenAPI Spec:** openapi.json
- **Frontend Guide:** docs/frontend-deployment.md
- **Production Guide:** PRODUCTION-README.md
- **Quick Start:** README.md
EOF
}

# Main execution
main() {
  local output_format="human"
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --json)
        output_format="json"
        shift
        ;;
      --markdown)
        output_format="markdown"
        shift
        ;;
      --help|-h)
        echo "Usage: $0 [--json|--markdown]"
        echo ""
        echo "Options:"
        echo "  --json       Output as JSON"
        echo "  --markdown   Output as Markdown"
        echo "  --help       Show this help message"
        exit 0
        ;;
      *)
        error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done
  
  check_prereqs
  get_terraform_outputs
  get_api_endpoints
  get_api_keys
  get_resource_status
  get_model_info
  
  case $output_format in
    json)
      output_json
      ;;
    markdown)
      output_markdown
      ;;
    *)
      display_deployment_details
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
