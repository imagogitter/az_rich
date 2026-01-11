# =============================================================================
# AZURE FUNCTIONS
# =============================================================================

resource "azurerm_application_insights" "main" {
  name                = local.app_insights_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"

  tags = local.tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = local.log_analytics_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.tags
}

resource "azurerm_service_plan" "functions" {
  name                = "${local.function_app_name}-plan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "Y1"  # Consumption plan

  tags = local.tags
}

resource "azurerm_linux_function_app" "main" {
  name                = local.function_app_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.functions.id

  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key

  functions_extension_version = "~4"

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME       = "python"
    AzureWebJobsStorage            = azurerm_storage_account.main.primary_connection_string
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.main.connection_string

    # Application settings
    KEY_VAULT_NAME     = azurerm_key_vault.main.name
    COSMOS_ACCOUNT     = azurerm_cosmosdb_account.main.name
    VMSS_NAME          = azurerm_linux_virtual_machine_scale_set.gpu.name
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }

    cors {
      allowed_origins = ["*"]
      support_credentials = false
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

# Grant Function App access to Key Vault
resource "azurerm_role_assignment" "func_kv_secrets" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

# Grant Function App access to Cosmos DB
resource "azurerm_cosmosdb_sql_role_assignment" "func_cosmos" {
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  role_definition_id  = azurerm_cosmosdb_account.main.id
  principal_id        = azurerm_linux_function_app.main.identity[0].principal_id
  scope               = azurerm_cosmosdb_account.main.id
}