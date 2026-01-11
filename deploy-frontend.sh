#!/usr/bin/env bash
set -euo pipefail

# Frontend deployment script for AI Inference Platform
# This script builds and deploys the Open WebUI frontend to Azure Container Apps

log() { echo -e "[INFO] $*"; }
error() { echo -e "[ERROR] $*" >&2; exit 1; }

# Check prerequisites
command -v az >/dev/null 2>&1 || error "Azure CLI not found"
command -v docker >/dev/null 2>&1 || error "Docker not found"

# Get resource names from Terraform outputs
RESOURCE_GROUP=$(cd terraform && terraform output -raw resource_group_name 2>/dev/null || echo "")
REGISTRY_NAME=$(cd terraform && terraform output -raw container_registry_name 2>/dev/null || echo "")
REGISTRY_LOGIN_SERVER=$(cd terraform && terraform output -raw container_registry_login_server 2>/dev/null || echo "")
FRONTEND_APP_NAME=$(cd terraform && terraform output -raw frontend_app_name 2>/dev/null || echo "")

if [ -z "$RESOURCE_GROUP" ] || [ -z "$REGISTRY_NAME" ] || [ -z "$REGISTRY_LOGIN_SERVER" ] || [ -z "$FRONTEND_APP_NAME" ]; then
  error "Could not get Terraform outputs. Run 'terraform apply' first."
fi

log "Using resource group: $RESOURCE_GROUP"
log "Using container registry: $REGISTRY_NAME"

# Login to Azure Container Registry
log "Logging in to Azure Container Registry..."
az acr login --name "$REGISTRY_NAME" || error "Failed to login to ACR"

# Build and tag the Docker image
log "Building Docker image..."
cd frontend
docker build -t open-webui:latest . || error "Failed to build Docker image"

# Tag for ACR
docker tag open-webui:latest "${REGISTRY_LOGIN_SERVER}/open-webui:latest" || error "Failed to tag image"

# Push to ACR
log "Pushing image to Azure Container Registry..."
docker push "${REGISTRY_LOGIN_SERVER}/open-webui:latest" || error "Failed to push image"

log "✅ Frontend image deployed successfully!"
log ""
log "To restart the container app with the new image:"
log "  az containerapp revision restart --name $FRONTEND_APP_NAME --resource-group $RESOURCE_GROUP"
log ""
log "To get the frontend URL:"
log "  cd terraform && terraform output frontend_url"
