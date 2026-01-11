# =============================================================================
# COSMOS DB (Serverless)
# =============================================================================

resource "azurerm_cosmosdb_account" "main" {
  name                = local.cosmos_account_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  
  # Serverless capacity mode for pay-per-request pricing
  capabilities {
    name = "EnableServerless"
  }
  
  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }
  
  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }
  
  tags = local.tags
}

# Cosmos DB SQL database for caching
resource "azurerm_cosmosdb_sql_database" "cache" {
  name                = "inference-cache"
  resource_group_name = azurerm_cosmosdb_account.main.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
}

# Cosmos DB container for response caching
resource "azurerm_cosmosdb_sql_container" "responses" {
  name                  = "responses"
  resource_group_name   = azurerm_cosmosdb_account.main.resource_group_name
  account_name          = azurerm_cosmosdb_account.main.name
  database_name         = azurerm_cosmosdb_sql_database.cache.name
  partition_key_path    = "/modelId"
  partition_key_version = 1
  
  indexing_policy {
    indexing_mode = "consistent"
    
    included_path {
      path = "/*"
    }
  }
  
  # TTL for cache expiration (24 hours)
  default_ttl = 86400
}

# Store Cosmos DB connection string in Key Vault
resource "azurerm_key_vault_secret" "cosmos_connection_string" {
  name         = "cosmos-connection-string"
  value        = azurerm_cosmosdb_account.main.primary_sql_connection_string
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [azurerm_role_assignment.kv_admin]
}
