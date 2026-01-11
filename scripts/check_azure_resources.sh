#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Azure Resources Congruency Check Script
# Compares deployed resources against expected architecture
# =============================================================================

PROJECT_NAME="${PROJECT_NAME:-ai-inference}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
LOCATION="${AZURE_LOCATION:-eastus}"
RESOURCE_GROUP="${PROJECT_NAME}-${ENVIRONMENT}-rg"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
EXPECTED_COUNT=0
DEPLOYED_COUNT=0
MISSING_COUNT=0

log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; DEPLOYED_COUNT=$((DEPLOYED_COUNT + 1)); }
log_missing() { echo -e "${RED}[✗]${NC} $*"; MISSING_COUNT=$((MISSING_COUNT + 1)); }
log_warn() { echo -e "${YELLOW}[!]${NC} $*"; }

check_prereqs() {
  log_info "Checking prerequisites..."
  
  if ! command -v az >/dev/null 2>&1; then
    echo "ERROR: Azure CLI not found. Install from: https://aka.ms/installazurecli"
    exit 1
  fi
  
  if ! az account show >/dev/null 2>&1; then
    echo "ERROR: Not logged into Azure. Run: az login"
    exit 1
  fi
  
  log_success "Azure CLI found and authenticated"
}

check_resource_group() {
  log_info "Checking Resource Group..."
  EXPECTED_COUNT=$((EXPECTED_COUNT + 1))
  
  if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
    LOCATION_ACTUAL=$(az group show --name "$RESOURCE_GROUP" --query location -o tsv)
    log_success "Resource Group: $RESOURCE_GROUP (location: $LOCATION_ACTUAL)"
  else
    log_missing "Resource Group: $RESOURCE_GROUP not found"
  fi
}

check_key_vault() {
  log_info "Checking Key Vault..."
  EXPECTED_COUNT=$((EXPECTED_COUNT + 1))
  
  KV_LIST=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null || echo "")
  
  if [ -n "$KV_LIST" ]; then
    for kv in $KV_LIST; do
      log_success "Key Vault: $kv"
    done
  else
    log_missing "Key Vault: No Key Vault found in $RESOURCE_GROUP"
  fi
}

check_storage_account() {
  log_info "Checking Storage Account..."
  EXPECTED_COUNT=$((EXPECTED_COUNT + 1))
  
  STORAGE_LIST=$(az storage account list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null || echo "")
  
  if [ -n "$STORAGE_LIST" ]; then
    for storage in $STORAGE_LIST; do
      SKU=$(az storage account show --name "$storage" --resource-group "$RESOURCE_GROUP" --query "sku.name" -o tsv)
      log_success "Storage Account: $storage (SKU: $SKU)"
    done
  else
    log_missing "Storage Account: No storage account found in $RESOURCE_GROUP"
  fi
}

check_cosmos_db() {
  log_info "Checking Cosmos DB..."
  EXPECTED_COUNT=$((EXPECTED_COUNT + 1))
  
  COSMOS_LIST=$(az cosmosdb list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null || echo "")
  
  if [ -n "$COSMOS_LIST" ]; then
    for cosmos in $COSMOS_LIST; do
      CAPABILITIES=$(az cosmosdb show --name "$cosmos" --resource-group "$RESOURCE_GROUP" --query "capabilities[].name" -o tsv)
      log_success "Cosmos DB: $cosmos (capabilities: ${CAPABILITIES:-none})"
    done
  else
    log_missing "Cosmos DB: No Cosmos DB account found in $RESOURCE_GROUP"
  fi
}

check_function_app() {
  log_info "Checking Function App..."
  EXPECTED_COUNT=$((EXPECTED_COUNT + 1))
  
  FUNC_LIST=$(az functionapp list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null || echo "")
  
  if [ -n "$FUNC_LIST" ]; then
    for func in $FUNC_LIST; do
      RUNTIME=$(az functionapp show --name "$func" --resource-group "$RESOURCE_GROUP" --query "siteConfig.linuxFxVersion" -o tsv)
      log_success "Function App: $func (runtime: ${RUNTIME:-unknown})"
    done
  else
    log_missing "Function App: No Function App found in $RESOURCE_GROUP"
  fi
}

check_vmss() {
  log_info "Checking VM Scale Set (GPU instances)..."
  EXPECTED_COUNT=$((EXPECTED_COUNT + 1))
  
  VMSS_LIST=$(az vmss list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null || echo "")
  
  if [ -n "$VMSS_LIST" ]; then
    for vmss in $VMSS_LIST; do
      SKU=$(az vmss show --name "$vmss" --resource-group "$RESOURCE_GROUP" --query "sku.name" -o tsv)
      PRIORITY=$(az vmss show --name "$vmss" --resource-group "$RESOURCE_GROUP" --query "virtualMachineProfile.priority" -o tsv)
      CAPACITY=$(az vmss show --name "$vmss" --resource-group "$RESOURCE_GROUP" --query "sku.capacity" -o tsv)
      log_success "VMSS: $vmss (SKU: $SKU, priority: $PRIORITY, capacity: $CAPACITY)"
    done
  else
    log_missing "VMSS: No VM Scale Set found in $RESOURCE_GROUP"
  fi
}

check_apim() {
  log_info "Checking API Management..."
  EXPECTED_COUNT=$((EXPECTED_COUNT + 1))
  
  APIM_LIST=$(az apim list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null || echo "")
  
  if [ -n "$APIM_LIST" ]; then
    for apim in $APIM_LIST; do
      SKU=$(az apim show --name "$apim" --resource-group "$RESOURCE_GROUP" --query "sku.name" -o tsv)
      log_success "API Management: $apim (SKU: $SKU)"
    done
  else
    log_missing "API Management: No APIM found in $RESOURCE_GROUP"
  fi
}

check_vnet() {
  log_info "Checking Virtual Network..."
  EXPECTED_COUNT=$((EXPECTED_COUNT + 1))
  
  VNET_LIST=$(az network vnet list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null || echo "")
  
  if [ -n "$VNET_LIST" ]; then
    for vnet in $VNET_LIST; do
      ADDRESS_SPACE=$(az network vnet show --name "$vnet" --resource-group "$RESOURCE_GROUP" --query "addressSpace.addressPrefixes[0]" -o tsv)
      log_success "Virtual Network: $vnet (address space: $ADDRESS_SPACE)"
    done
  else
    log_missing "Virtual Network: No VNet found in $RESOURCE_GROUP"
  fi
}

check_log_analytics() {
  log_info "Checking Log Analytics Workspace..."
  EXPECTED_COUNT=$((EXPECTED_COUNT + 1))
  
  LA_LIST=$(az monitor log-analytics workspace list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null || echo "")
  
  if [ -n "$LA_LIST" ]; then
    for la in $LA_LIST; do
      SKU=$(az monitor log-analytics workspace show --workspace-name "$la" --resource-group "$RESOURCE_GROUP" --query "sku.name" -o tsv)
      log_success "Log Analytics: $la (SKU: $SKU)"
    done
  else
    log_missing "Log Analytics: No workspace found in $RESOURCE_GROUP"
  fi
}

check_app_insights() {
  log_info "Checking Application Insights..."
  EXPECTED_COUNT=$((EXPECTED_COUNT + 1))
  
  AI_LIST=$(az monitor app-insights component show --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null || echo "")
  
  if [ -n "$AI_LIST" ]; then
    for ai in $AI_LIST; do
      log_success "Application Insights: $ai"
    done
  else
    log_missing "Application Insights: No App Insights found in $RESOURCE_GROUP"
  fi
}

print_summary() {
  echo ""
  echo "============================================="
  echo "Azure Resources Congruency Report"
  echo "============================================="
  echo "Resource Group: $RESOURCE_GROUP"
  echo "Expected Resources: $EXPECTED_COUNT"
  echo "Deployed Resources: $DEPLOYED_COUNT"
  echo "Missing Resources: $MISSING_COUNT"
  echo ""
  
  if [ $MISSING_COUNT -eq 0 ]; then
    log_success "All expected resources are deployed! ✓"
    echo ""
    echo "Status: FULLY CONGRUENT"
    exit 0
  else
    log_warn "Some resources are missing from deployment"
    echo ""
    echo "Status: NOT CONGRUENT"
    echo ""
    echo "To deploy missing resources, run:"
    echo "  cd terraform && terraform init && terraform apply"
    echo "  OR"
    echo "  ./deploy-full-clean.sh"
    exit 1
  fi
}

main() {
  echo "============================================="
  echo "Azure Resources Congruency Check"
  echo "============================================="
  echo ""
  
  check_prereqs
  echo ""
  
  check_resource_group
  check_key_vault
  check_storage_account
  check_cosmos_db
  check_function_app
  check_vmss
  check_apim
  check_vnet
  check_log_analytics
  check_app_insights
  
  print_summary
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
