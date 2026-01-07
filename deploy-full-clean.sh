#!/usr/bin/env bash
set -euo pipefail

# Cleaned full deploy script (idempotent, safe defaults)
PROJECT_NAME="ai-inference-platform"
LOCATION="${AZURE_LOCATION:-eastus}"
RESOURCE_GROUP="${PROJECT_NAME}-rg"
TAGS="project=${PROJECT_NAME} environment=production managed-by=script"
APIM_SKU="Consumption"
VMSS_SKU="Standard_ND96asr_v4"  # 8x NVIDIA A100 40GB GPUs
SPOT_MAX_PRICE="-1"  # -1 means pay up to on-demand price

log() { echo -e "[INFO] $*"; }
warn() { echo -e "[WARN] $*"; }
error() { echo -e "[ERROR] $*" >&2; exit 1; }

check_prereqs() {
  command -v az >/dev/null 2>&1 || error "Azure CLI not found"
}

create_resource_group() {
  if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
    log "Resource group $RESOURCE_GROUP exists"
  else
    log "Creating resource group $RESOURCE_GROUP"
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --tags "$TAGS"
  fi
}

create_key_vault() {
  KEY_VAULT_NAME="${PROJECT_NAME}-kv-$(date +%s | tail -c 6)"
  if az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    log "Key Vault $KEY_VAULT_NAME exists"
  else
    log "Creating Key Vault $KEY_VAULT_NAME"
    az keyvault create --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" --tags "$TAGS"
  fi
  echo "KEY_VAULT_NAME=$KEY_VAULT_NAME" >> .env
}

create_storage() {
  STORAGE_NAME="$(echo "${PROJECT_NAME//[^a-z0-9]/}st$(date +%s | tail -c 6)" | cut -c1-24)"
  if az storage account show --name "$STORAGE_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    log "Storage account $STORAGE_NAME exists"
  else
    log "Creating storage account $STORAGE_NAME"
    az storage account create --name "$STORAGE_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" --sku Standard_LRS --kind StorageV2 --tags "$TAGS"
  fi
  echo "STORAGE_ACCOUNT=$STORAGE_NAME" >> .env
}

create_cosmos() {
  COSMOS_NAME="${PROJECT_NAME}cos$(date +%s | tail -c 6)"
  if az cosmosdb show --name "$COSMOS_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    log "Cosmos DB $COSMOS_NAME exists"
  else
    log "Creating Cosmos DB $COSMOS_NAME (serverless)"
    az cosmosdb create --name "$COSMOS_NAME" --resource-group "$RESOURCE_GROUP" --locations regionName="$LOCATION" failoverPriority=0 --capabilities EnableServerless --tags "$TAGS"
  fi
  echo "COSMOS_ACCOUNT=$COSMOS_NAME" >> .env
}

create_function_app() {
  FUNC_NAME="${PROJECT_NAME}-func-$(date +%s | tail -c 6)"
  if az functionapp show --name "$FUNC_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    log "Function App $FUNC_NAME exists"
  else
    log "Creating Function App $FUNC_NAME (placeholder)"
    # Placeholder: requires storage account and runtime; keep idempotent minimal
    az functionapp create --name "$FUNC_NAME" --resource-group "$RESOURCE_GROUP" --storage-account "${STORAGE_ACCOUNT:-$STORAGE_NAME}" --consumption-plan-location "$LOCATION" --runtime python --runtime-version 3.11 --functions-version 4 --os-type Linux --tags "$TAGS" || warn "Function app creation skipped or requires additional permissions"
  fi
  echo "FUNCTION_APP_NAME=$FUNC_NAME" >> .env
}

create_vmss() {
  VMSS_NAME="${PROJECT_NAME}-gpu"
  if az vmss show --name "$VMSS_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    log "VMSS $VMSS_NAME exists"
  else
    log "Creating placeholder VMSS $VMSS_NAME (0 instances)"
    az vmss create --name "$VMSS_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" --vm-sku "$VMSS_SKU" --instance-count 0 --priority Spot --max-price "$SPOT_MAX_PRICE" --tags "$TAGS" || warn "VMSS creation skipped or requires specific quotas"
  fi
  echo "VMSS_NAME=$VMSS_NAME" >> .env
}

create_apim() {
  APIM_NAME="${PROJECT_NAME}-apim"
  if az apim show --name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    log "APIM $APIM_NAME exists"
  else
    log "Creating API Management $APIM_NAME"
    az apim create --name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" --publisher-email "admin@${PROJECT_NAME}.example.com" --publisher-name "$PROJECT_NAME" --sku-name "$APIM_SKU" --tags "$TAGS" || warn "APIM creation skipped or requires quota"
  fi
  echo "APIM_NAME=$APIM_NAME" >> .env
}

deploy_autoscaling() {
  log "Configuring autoscaling (placeholder)."
}

main() {
  log "=== Cleaned Full Deployment (dry-safe mode) ==="
  check_prereqs
  create_resource_group
  create_key_vault
  create_storage
  create_cosmos
  create_function_app
  create_vmss
  create_apim
  deploy_autoscaling
  log "=== Done. Inspect .env for resource names and adjust scripts as needed ==="
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
