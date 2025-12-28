#!/usr/bin/env bash
set -euo pipefail

# Clean simplified deployment script (safe, idempotent core steps)
PROJECT_NAME="ai-inference-platform"
LOCATION="${AZURE_LOCATION:-eastus}"
RESOURCE_GROUP="${PROJECT_NAME}-rg"
TAGS="project=${PROJECT_NAME} environment=prod"

log() { echo -e "[INFO] $*"; }
error() { echo -e "[ERROR] $*" >&2; exit 1; }

check_prereqs() {
  command -v az >/dev/null 2>&1 || error "Azure CLI not found. Install: https://aka.ms/installazurecli"
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
    log "Key Vault $KEY_VAULT_NAME already exists"
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

main() {
  check_prereqs
  create_resource_group
  create_key_vault
  create_storage
  create_cosmos
  log "Clean deployment steps completed. Inspect .env for resource names."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
