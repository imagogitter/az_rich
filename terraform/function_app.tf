# =============================================================================
# FUNCTION APP
# =============================================================================

# App Service Plan for Function App (Consumption)
resource "azurerm_service_plan" "main" {
  name                = "${var.project_name}-plan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption plan
  
  tags = local.tags
}

# Function App
resource "azurerm_linux_function_app" "main" {
  name                       = local.function_app_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  service_plan_id            = azurerm_service_plan.main.id
  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key
  
  site_config {
    application_stack {
      python_version = "3.11"
    }
    
    application_insights_key               = azurerm_application_insights.main.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.main.connection_string
    
    # Enable CORS for API access
    cors {
      allowed_origins = ["*"]
    }
  }
  
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "python"
    "COSMOS_CONNECTION_STRING"       = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=cosmos-connection-string)"
    "KEY_VAULT_NAME"                 = azurerm_key_vault.main.name
    "INFERENCE_API_KEY"              = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=inference-api-key)"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.main.instrumentation_key
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = local.tags
}

# Grant Function App access to Key Vault secrets
resource "azurerm_role_assignment" "function_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

# Grant Function App access to Cosmos DB
resource "azurerm_cosmosdb_sql_role_assignment" "function_cosmos" {
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  role_definition_id  = "${azurerm_cosmosdb_account.main.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002" # Built-in Data Contributor
  principal_id        = azurerm_linux_function_app.main.identity[0].principal_id
  scope               = azurerm_cosmosdb_account.main.id
}
