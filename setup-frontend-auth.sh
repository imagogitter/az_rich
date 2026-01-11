#!/usr/bin/env bash
set -euo pipefail

# Post-deployment setup script for AI Inference Platform Frontend
# Run this after creating your admin account to secure the frontend

log() { echo -e "[INFO] $*"; }
warn() { echo -e "[WARN] $*"; }
error() { echo -e "[ERROR] $*" >&2; exit 1; }

# Check prerequisites
command -v az >/dev/null 2>&1 || error "Azure CLI not found"

# Get resource names from Terraform outputs
RESOURCE_GROUP=$(cd terraform && terraform output -raw resource_group_name 2>/dev/null || echo "")
FRONTEND_URL=$(cd terraform && terraform output -raw frontend_url 2>/dev/null || echo "")
FRONTEND_APP_NAME=$(cd terraform && terraform output -raw frontend_app_name 2>/dev/null || echo "")

if [ -z "$RESOURCE_GROUP" ] || [ -z "$FRONTEND_APP_NAME" ]; then
  error "Could not get Terraform outputs. Run 'terraform apply' first."
fi

log "Frontend URL: $FRONTEND_URL"
log ""

# Prompt user confirmation
echo "This script will disable public signup to secure your frontend."
echo "Make sure you have already created your admin account!"
echo ""
read -p "Have you created your admin account? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
  warn "Please create your admin account first by visiting: $FRONTEND_URL"
  warn "Then run this script again."
  exit 0
fi

log "Disabling public signup..."
az containerapp update \
  --name "$FRONTEND_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --set-env-vars "ENABLE_SIGNUP=false" \
  || error "Failed to update container app"

log "Waiting for update to apply..."
sleep 5

log "Restarting container app..."
az containerapp revision restart \
  --name "$FRONTEND_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  || warn "Failed to restart. The app should restart automatically."

log ""
log "✅ Frontend secured! Public signup is now disabled."
log ""
log "Frontend URL: $FRONTEND_URL"
log ""
log "To manage users, login as admin and go to Admin Settings > Users"
log ""
log "To temporarily enable signup for adding new users:"
log "  az containerapp update \\"
log "    --name $FRONTEND_APP_NAME \\"
log "    --resource-group $RESOURCE_GROUP \\"
log "    --set-env-vars \"ENABLE_SIGNUP=true\""
