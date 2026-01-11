# =============================================================================
# STORAGE ACCOUNT
# =============================================================================

resource "azurerm_storage_account" "main" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  
  # Security settings
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  
  tags = local.tags
}

# Storage container for function app deployments
resource "azurerm_storage_container" "deployments" {
  name                  = "deployments"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Storage container for cache data
resource "azurerm_storage_container" "cache" {
  name                  = "cache"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}
