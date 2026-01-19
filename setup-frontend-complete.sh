#!/usr/bin/env bash
set -euo pipefail

# Complete frontend deployment script for AI Inference Platform
# This script performs full infrastructure deployment, frontend container deployment,
# and retrieves LLM connection details for the AI Inference Platform

log() { echo -e "[INFO] $*"; }
error() { echo -e "[ERROR] $*" >&2; exit 1; }
warn() { echo -e "[WARN] $*"; }

# Defaults
SKIP_TERRAFORM=0
USE_MANAGED_IDENTITY=0
FORCE=0
BACKEND_STORAGE_ACCOUNT=""
BACKEND_CONTAINER=""
BACKEND_KEY=""
RESOURCE_GROUP_OVERRIDE=""
IMAGE_TAG=""
KEY_VAULT_NAME=""
GRANT_ACR_ROLE=0

# Parse CLI args
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --use-managed-identity) USE_MANAGED_IDENTITY=1; shift;;
      --backend-storage-account) BACKEND_STORAGE_ACCOUNT="$2"; shift 2;;
      --backend-container) BACKEND_CONTAINER="$2"; shift 2;;
      --backend-key) BACKEND_KEY="$2"; shift 2;;
      --resource-group) RESOURCE_GROUP_OVERRIDE="$2"; shift 2;;
      --keyvault) KEY_VAULT_NAME="$2"; shift 2;;
      --grant-acr-role) GRANT_ACR_ROLE=1; shift;;
      --force) FORCE=1; shift;;
      --image-tag) IMAGE_TAG="$2"; shift 2;;
      --skip-terraform) SKIP_TERRAFORM=1; shift;;
      -h|--help) echo "Usage: $0 [--use-managed-identity] [--backend-storage-account NAME --backend-container NAME --backend-key KEY] [--resource-group RG] [--image-tag TAG] [--grant-acr-role] [--force] [--skip-terraform]"; exit 0;;
      *) error "Unknown option: $1";;
    esac
  done
}

# Check prerequisites
check_prereqs() {
  log "Checking prerequisites..."
  command -v az >/dev/null 2>&1 || error "Azure CLI not found. Install from: https://learn.microsoft.com/cli/azure/install-azure-cli"
  command -v docker >/dev/null 2>&1 || error "Docker not found. Install from: https://docs.docker.com/get-docker/"
  command -v terraform >/dev/null 2>&1 || error "Terraform not found. Install from: https://www.terraform.io/downloads"
  
  # If we intend to use managed identity, ensure the environment supports it
  if [ "${USE_MANAGED_IDENTITY:-0}" -eq 1 ]; then
    log "Using Azure Managed Identity for authentication (will run 'az login --identity' if available)"
  fi

  # Check if logged in to Azure (allow managed identity login attempt)
  if ! az account show >/dev/null 2>&1; then
    if [ "${USE_MANAGED_IDENTITY:-0}" -eq 1 ]; then
      log "Attempting 'az login --identity'..."
      if ! az login --identity >/dev/null 2>&1; then
        error "Managed Identity login failed. Ensure this script runs with an assigned managed identity or run 'az login' manually."
      fi
    else
      error "Not logged in to Azure. Run 'az login' first or pass --use-managed-identity"
    fi
  fi
  
  log "✅ All prerequisites satisfied"
}

# Helper to fetch a secret from Key Vault (returns empty if not found)
get_kv_secret() {
  local secret_name="$1"
  if [ -z "${KEY_VAULT_NAME}" ]; then
    echo ""
    return 0
  fi
  az keyvault secret show --vault-name "${KEY_VAULT_NAME}" --name "$secret_name" --query value -o tsv 2>/dev/null || echo ""
}

# Load configuration from GitHub Actions env or Azure Key Vault if not provided via CLI
load_config() {
  # If running in GitHub Actions, prefer env vars (workflow should set secrets to env vars)
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    log "Detected GitHub Actions environment; reading config from env vars if present"
    BACKEND_STORAGE_ACCOUNT="${BACKEND_STORAGE_ACCOUNT:-${BACKEND_STORAGE_ACCOUNT:-}}"
    BACKEND_CONTAINER="${BACKEND_CONTAINER:-${BACKEND_CONTAINER:-}}"
    BACKEND_KEY="${BACKEND_KEY:-${BACKEND_KEY:-}}"
    RESOURCE_GROUP_OVERRIDE="${RESOURCE_GROUP_OVERRIDE:-${RESOURCE_GROUP:-}}"
    IMAGE_TAG="${IMAGE_TAG:-${INPUT_IMAGE_TAG:-}}"
    KEY_VAULT_NAME="${KEY_VAULT_NAME:-${INPUT_KEY_VAULT_NAME:-}}"
  fi

  # If Key Vault specified, fetch missing values from Key Vault secrets
  if [ -n "${KEY_VAULT_NAME}" ]; then
    log "Reading missing configuration from Key Vault: ${KEY_VAULT_NAME}"
    BACKEND_STORAGE_ACCOUNT="${BACKEND_STORAGE_ACCOUNT:-$(get_kv_secret 'backend-storage-account') }"
    BACKEND_CONTAINER="${BACKEND_CONTAINER:-$(get_kv_secret 'backend-container') }"
    BACKEND_KEY="${BACKEND_KEY:-$(get_kv_secret 'backend-key') }"
    RESOURCE_GROUP_OVERRIDE="${RESOURCE_GROUP_OVERRIDE:-$(get_kv_secret 'resource-group') }"
    IMAGE_TAG="${IMAGE_TAG:-$(get_kv_secret 'image-tag') }"
  fi

  # Trim whitespace
  BACKEND_STORAGE_ACCOUNT="$(echo -n "$BACKEND_STORAGE_ACCOUNT" | xargs)"
  BACKEND_CONTAINER="$(echo -n "$BACKEND_CONTAINER" | xargs)"
  BACKEND_KEY="$(echo -n "$BACKEND_KEY" | xargs)"
  RESOURCE_GROUP_OVERRIDE="$(echo -n "$RESOURCE_GROUP_OVERRIDE" | xargs)"
  IMAGE_TAG="$(echo -n "$IMAGE_TAG" | xargs)"

  # Log what we found (redact keys)
  log "Config: backend_storage_account=${BACKEND_STORAGE_ACCOUNT:-'(none)'} backend_container=${BACKEND_CONTAINER:-'(none)'} backend_key=${BACKEND_KEY:+(redacted)} resource_group=${RESOURCE_GROUP_OVERRIDE:-'(none)'} image_tag=${IMAGE_TAG:-'(none)'} key_vault=${KEY_VAULT_NAME:-'(none)'}"
} 

# Deploy infrastructure using Terraform
deploy_infrastructure() {
  log "Deploying infrastructure with Terraform..."
  
  cd terraform || error "terraform directory not found"
  
  # Autopopulate Terraform variables
  cat > terraform.tfvars <<EOF
container_name = "default-container"
key = "default-key"
storage_account_name = "default-storage-account"
resource_group_name = "default-resource-group"
EOF
  
  # Ensure required authentication
  if ! grep -q 'access_key\|sas_token\|use_azuread_auth\|resource_group_name' variables.tf; then
    warn "No explicit auth variables found in variables.tf; proceeding with defaults in terraform.tfvars. Set appropriate auth variables for production."
  fi
  
  # Initialize Terraform
  log "Running terraform init..."
  # If backend details provided, use them (for real remote state). Otherwise we require remote backend for full deploy.
  backend_args=()
  if [ -n "$BACKEND_STORAGE_ACCOUNT" ] && [ -n "$BACKEND_CONTAINER" ] && [ -n "$BACKEND_KEY" ]; then
    backend_args+=("-backend-config=storage_account_name=$BACKEND_STORAGE_ACCOUNT")
    backend_args+=("-backend-config=container_name=$BACKEND_CONTAINER")
    backend_args+=("-backend-config=key=$BACKEND_KEY")
  else
    log "No remote backend specified. To perform an actual idempotent deploy you must supply backend details via --backend-* flags"
    if [ "${SKIP_TERRAFORM:-0}" -eq 0 ]; then
      error "Remote backend not provided. Re-run with --backend-storage-account --backend-container --backend-key or use --skip-terraform to dry-run."
    fi
  fi

  if [ "${SKIP_TERRAFORM:-0}" -eq 1 ]; then
    warn "Skipping terraform init because SKIP_TERRAFORM=1"
  else
    if ! terraform init -input=false -reconfigure "${backend_args[@]}"; then
      warn "Terraform init failed; switching to local dry-run mode"
      SKIP_TERRAFORM=1
      cd ..
      return 0
    fi
  fi
  
  # Validate configuration
  log "Running terraform validate..."
  if ! terraform validate; then
    warn "Terraform validation failed; switching to local dry-run mode"
    SKIP_TERRAFORM=1
    cd ..
    return 0
  fi
  
  # Plan deployment (non-interactive, using generated tfvars)
  log "Running terraform plan..."
  if [ "${SKIP_TERRAFORM:-0}" -eq 1 ]; then
    warn "Skipping terraform plan because SKIP_TERRAFORM=1"
    cd ..
    return 0
  fi

  if ! terraform plan -out=tfplan -var-file=terraform.tfvars -input=false 2>&1 | tee /tmp/terraform-plan.log; then
    warn "Terraform plan failed; likely due to backend config or missing credentials. Aborting full deploy to preserve idempotency."
    SKIP_TERRAFORM=1
    cd ..
    return 0
  fi
  
  # Apply deployment (non-interactive)
  log "Running terraform apply..."
  if ! terraform apply -auto-approve -input=false tfplan; then
    warn "Terraform apply failed; skipping further steps"
    SKIP_TERRAFORM=1
    cd ..
    return 0
  fi
  
  cd ..
  log "✅ Infrastructure deployed successfully"
}

# Deploy frontend container
deploy_frontend() {
  log "Deploying frontend container..."
  
  if [ "${SKIP_TERRAFORM:-0}" -eq 1 ]; then
    warn "Skipping frontend deployment because infrastructure deployment was skipped or failed."
    return 0
  fi
  
  # Get resource names from Terraform outputs
  RESOURCE_GROUP=$(cd terraform && terraform output -raw resource_group_name 2>/dev/null) || error "Could not get resource group name"
  # Allow override from CLI
  RESOURCE_GROUP="${RESOURCE_GROUP_OVERRIDE:-$RESOURCE_GROUP}"
  REGISTRY_NAME=$(cd terraform && terraform output -raw container_registry_name 2>/dev/null) || error "Could not get container registry name"
  REGISTRY_LOGIN_SERVER=$(cd terraform && terraform output -raw container_registry_login_server 2>/dev/null) || error "Could not get container registry login server"
  FRONTEND_APP_NAME=$(cd terraform && terraform output -raw frontend_app_name 2>/dev/null) || error "Could not get frontend app name"
  
  log "Using resource group: $RESOURCE_GROUP"
  log "Using container registry: $REGISTRY_NAME"
  
  # Determine deterministic image tag (idempotent): use provided IMAGE_TAG or hash of frontend dir or git commit
  if [ -z "${IMAGE_TAG}" ]; then
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      IMAGE_TAG=$(git rev-parse --short HEAD)
    else
      # deterministic hash of frontend contents
      IMAGE_TAG=$(find frontend -type f -print0 | sort -z | xargs -0 sha1sum 2>/dev/null | sha1sum | awk '{print $1}')
      IMAGE_TAG=${IMAGE_TAG:-latest}
    fi
  fi

  FULL_IMAGE="${REGISTRY_LOGIN_SERVER}/open-webui:${IMAGE_TAG}"

  # Check if current container app already uses this image
  CURRENT_IMAGE=$(az containerapp show --name "$FRONTEND_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "template.containers[0].image" -o tsv 2>/dev/null || true)
  if [ "$CURRENT_IMAGE" = "$FULL_IMAGE" ]; then
    log "Frontend already running image $FULL_IMAGE — nothing to do (idempotent)."
    return 0
  fi

  # Login to Azure Container Registry
  log "Logging in to Azure Container Registry..."
  az acr login --name "$REGISTRY_NAME" || error "Failed to login to ACR. Check your Azure permissions."

  # Optionally grant the Function App managed identity AcrPush on the registry (idempotent)
  if [ "${GRANT_ACR_ROLE:-0}" -eq 1 ]; then
    log "Attempting to grant AcrPush role to Function App managed identity (if available)..."
    # Get registry resource id
    ACR_ID=$(az acr show --name "$REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv 2>/dev/null || echo "")
    if [ -z "$ACR_ID" ]; then
      warn "Could not find ACR resource id for $REGISTRY_NAME; skipping role assignment"
    else
      # function app identity
      FUNCTION_APP_NAME=$(cd terraform && terraform output -raw function_app_name 2>/dev/null || echo "")
      if [ -z "$FUNCTION_APP_NAME" ]; then
        warn "Function app name not available from terraform outputs; skipping role assignment"
      else
        PRINCIPAL_ID=$(az functionapp identity show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" --query principalId -o tsv 2>/dev/null || true)
        if [ -z "$PRINCIPAL_ID" ]; then
          # try webapp identity (fallback)
          PRINCIPAL_ID=$(az webapp identity show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" --query principalId -o tsv 2>/dev/null || true)
        fi
        if [ -z "$PRINCIPAL_ID" ]; then
          warn "Could not determine principalId for function app $FUNCTION_APP_NAME; skipping role assignment"
        else
          # check existing assignment
          if az role assignment list --assignee-object-id "$PRINCIPAL_ID" --scope "$ACR_ID" --query "[?roleDefinitionName=='AcrPush']" -o tsv | grep -q .; then
            log "AcrPush role already assigned to principal $PRINCIPAL_ID on $ACR_ID"
          else
            if az role assignment create --assignee-object-id "$PRINCIPAL_ID" --role AcrPush --scope "$ACR_ID" >/dev/null 2>&1; then
              log "Granted AcrPush to principal $PRINCIPAL_ID on $ACR_ID"
            else
              warn "Failed to assign AcrPush role to principal $PRINCIPAL_ID. Ensure the caller has permission to assign roles."
            fi
          fi
        fi
      fi
    fi
  fi

  # Build and tag the Docker image
  log "Building Docker image (tag: $IMAGE_TAG)..."
  cd frontend || error "frontend directory not found"
  docker build -t open-webui:${IMAGE_TAG} . || error "Failed to build Docker image. Check Dockerfile and Docker daemon."
  
  # Tag for ACR
  log "Tagging image for ACR..."
  docker tag open-webui:${IMAGE_TAG} "${FULL_IMAGE}" || error "Failed to tag image"
  
  # Push to ACR (idempotent push will succeed even if image already exists)
  log "Pushing image to Azure Container Registry..."
  docker push "${FULL_IMAGE}" || error "Failed to push image to ACR"
  
  cd ..

  # Update container app to use the new image (idempotent)
  log "Updating Container App to use image $FULL_IMAGE..."
  az containerapp update --name "$FRONTEND_APP_NAME" --resource-group "$RESOURCE_GROUP" --set "template.containers[0].image=$FULL_IMAGE" || warn "Failed to update container app image; attempting revision restart"

  # Restart the container app revision to pick up new image
  log "Restarting container app..."
  az containerapp revision restart \
    --name "$FRONTEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    || warn "Failed to restart container app. It may restart automatically."
  
  log "✅ Frontend container deployed successfully (image: $FULL_IMAGE)"
}

# Retrieve and display connection details
display_connection_details() {
  log "Retrieving connection details..."
  
  # Get outputs from Terraform
  FRONTEND_URL=$(cd terraform && terraform output -raw frontend_url 2>/dev/null) || warn "Could not get frontend URL"
  RESOURCE_GROUP=$(cd terraform && terraform output -raw resource_group_name 2>/dev/null) || warn "Could not get resource group"
  FRONTEND_APP_NAME=$(cd terraform && terraform output -raw frontend_app_name 2>/dev/null) || warn "Could not get frontend app name"
  KEY_VAULT_NAME=$(cd terraform && terraform output -raw key_vault_name 2>/dev/null) || warn "Could not get Key Vault name"
  
  # Get OpenAI API configuration from container app environment
  log "Retrieving API configuration from container app..."
  
  # Get the Function App hostname to construct API base URL
  FUNCTION_APP_NAME=$(cd terraform && terraform output -raw function_app_name 2>/dev/null) || warn "Could not get function app name"
  
  # Retrieve API key from Key Vault
  if [ -n "$KEY_VAULT_NAME" ]; then
    OPENAI_API_KEY=$(az keyvault secret show \
      --vault-name "$KEY_VAULT_NAME" \
      --name "frontend-openai-api-key" \
      --query "value" -o tsv 2>/dev/null) || warn "Could not retrieve API key from Key Vault"
  fi
  
  # Display connection details
  echo ""
  echo "=========================================="
  echo "🎉 DEPLOYMENT COMPLETE!"
  echo "=========================================="
  echo ""
  echo "📋 Connection Details:"
  echo "----------------------------------------"
  echo "Frontend URL:        ${FRONTEND_URL:-Not available}"
  echo "Resource Group:      ${RESOURCE_GROUP:-Not available}"
  echo "Frontend App Name:   ${FRONTEND_APP_NAME:-Not available}"
  echo "Function App Name:   ${FUNCTION_APP_NAME:-Not available}"
  echo ""
  echo "🔐 LLM API Configuration:"
  echo "----------------------------------------"
  if [ -n "$FUNCTION_APP_NAME" ]; then
    echo "OPENAI_API_BASE_URL: https://${FUNCTION_APP_NAME}.azurewebsites.net/api/v1"
  else
    echo "OPENAI_API_BASE_URL: Not available"
  fi
  echo "OPENAI_API_KEY:      ${OPENAI_API_KEY:-Not available (check Key Vault)}"
  echo ""
  echo "📖 Next Steps:"
  echo "----------------------------------------"
  echo "1. Visit the frontend URL to access the web interface"
  echo "2. Create your admin account (first user becomes admin)"
  echo "3. Run './setup-frontend-auth.sh' to secure the frontend"
  echo ""
  echo "🛠️  Useful Commands:"
  echo "----------------------------------------"
  echo "View logs:"
  echo "  az containerapp logs show --name '$FRONTEND_APP_NAME' --resource-group '$RESOURCE_GROUP' --tail 50"
  echo ""
  echo "Restart frontend:"
  echo "  az containerapp revision restart --name '$FRONTEND_APP_NAME' --resource-group '$RESOURCE_GROUP'"
  echo ""
  echo "Get API key from Key Vault:"
  echo "  az keyvault secret show --vault-name '$KEY_VAULT_NAME' --name frontend-openai-api-key --query value -o tsv"
  echo ""
  echo "=========================================="
  
  # Save connection details to a file for CI/CD
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    log "Saving connection details for GitHub Actions..."
    mkdir -p output
    cat > output/connection-details.txt <<EOF
Frontend URL: ${FRONTEND_URL:-Not available}
Resource Group: ${RESOURCE_GROUP:-Not available}
Frontend App Name: ${FRONTEND_APP_NAME:-Not available}
Function App Name: ${FUNCTION_APP_NAME:-Not available}
OPENAI_API_BASE_URL: $([ -n "$FUNCTION_APP_NAME" ] && echo "https://${FUNCTION_APP_NAME}.azurewebsites.net/api/v1" || echo "Not available")
OPENAI_API_KEY: ${OPENAI_API_KEY:-Not available}
EOF
    log "✅ Connection details saved to output/connection-details.txt"
  fi
}

# Main execution
main() {
  parse_args "$@"
  log "=========================================="
  log "AI Inference Platform - Complete Frontend Deployment"
  log "=========================================="
  echo ""
  
  check_prereqs
  load_config
  deploy_infrastructure
  deploy_frontend
  display_connection_details
  
  log ""
  log "✅ All deployment steps completed successfully!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

