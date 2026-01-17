#!/usr/bin/env bash
set -euo pipefail

# Complete frontend deployment script for AI Inference Platform
# This script performs full infrastructure deployment, frontend container deployment,
# and retrieves LLM connection details for the AI Inference Platform

log() { echo -e "[INFO] $*"; }
error() { echo -e "[ERROR] $*" >&2; exit 1; }
warn() { echo -e "[WARN] $*"; }

# Check prerequisites
check_prereqs() {
  log "Checking prerequisites..."
  command -v az >/dev/null 2>&1 || error "Azure CLI not found. Install from: https://learn.microsoft.com/cli/azure/install-azure-cli"
  command -v docker >/dev/null 2>&1 || error "Docker not found. Install from: https://docs.docker.com/get-docker/"
  command -v terraform >/dev/null 2>&1 || error "Terraform not found. Install from: https://www.terraform.io/downloads"
  
  # Check if logged in to Azure
  az account show >/dev/null 2>&1 || error "Not logged in to Azure. Run 'az login' first."
  
  log "✅ All prerequisites satisfied"
}

# Deploy infrastructure using Terraform
deploy_infrastructure() {
  log "Deploying infrastructure with Terraform..."
  
  cd terraform || error "terraform directory not found"
  
  # Initialize Terraform
  log "Running terraform init..."
  terraform init || error "Terraform init failed"
  
  # Validate configuration
  log "Running terraform validate..."
  terraform validate || error "Terraform validation failed"
  
  # Plan deployment
  log "Running terraform plan..."
  terraform plan -out=tfplan || error "Terraform plan failed"
  
  # Apply deployment
  log "Running terraform apply..."
  terraform apply -auto-approve tfplan || error "Terraform apply failed"
  
  cd ..
  log "✅ Infrastructure deployed successfully"
}

# Deploy frontend container
deploy_frontend() {
  log "Deploying frontend container..."
  
  # Get resource names from Terraform outputs
  RESOURCE_GROUP=$(cd terraform && terraform output -raw resource_group_name 2>/dev/null) || error "Could not get resource group name"
  REGISTRY_NAME=$(cd terraform && terraform output -raw container_registry_name 2>/dev/null) || error "Could not get container registry name"
  REGISTRY_LOGIN_SERVER=$(cd terraform && terraform output -raw container_registry_login_server 2>/dev/null) || error "Could not get container registry login server"
  FRONTEND_APP_NAME=$(cd terraform && terraform output -raw frontend_app_name 2>/dev/null) || error "Could not get frontend app name"
  
  log "Using resource group: $RESOURCE_GROUP"
  log "Using container registry: $REGISTRY_NAME"
  
  # Login to Azure Container Registry
  log "Logging in to Azure Container Registry..."
  az acr login --name "$REGISTRY_NAME" || error "Failed to login to ACR. Check your Azure permissions."
  
  # Build and tag the Docker image
  log "Building Docker image..."
  cd frontend || error "frontend directory not found"
  docker build -t open-webui:latest . || error "Failed to build Docker image. Check Dockerfile and Docker daemon."
  
  # Tag for ACR
  log "Tagging image for ACR..."
  docker tag open-webui:latest "${REGISTRY_LOGIN_SERVER}/open-webui:latest" || error "Failed to tag image"
  
  # Push to ACR
  log "Pushing image to Azure Container Registry..."
  docker push "${REGISTRY_LOGIN_SERVER}/open-webui:latest" || error "Failed to push image to ACR"
  
  cd ..
  
  # Restart the container app to use the new image
  log "Restarting container app..."
  az containerapp revision restart \
    --name "$FRONTEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    || warn "Failed to restart container app. It may restart automatically."
  
  log "✅ Frontend container deployed successfully"
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
  log "=========================================="
  log "AI Inference Platform - Complete Frontend Deployment"
  log "=========================================="
  echo ""
  
  check_prereqs
  deploy_infrastructure
  deploy_frontend
  display_connection_details
  
  log ""
  log "✅ All deployment steps completed successfully!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
