# =============================================================================
# KEY VAULT
# =============================================================================

resource "azurerm_key_vault" "main" {
  name                = local.key_vault_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  
  enable_rbac_authorization       = true
  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  soft_delete_retention_days      = 7
  purge_protection_enabled        = false
  
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
  
  tags = local.tags
}

# Grant current user Key Vault Administrator
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Generate and store API key
resource "random_password" "api_key" {
  length  = 64
  special = false
}

resource "azurerm_key_vault_secret" "inference_api_key" {
  name         = "inference-api-key"
  value        = random_password.api_key.result
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [azurerm_role_assignment.kv_admin]
}

# Generate internal service key
resource "random_password" "internal_key" {
  length  = 64
  special = false
}

resource "azurerm_key_vault_secret" "internal_service_key" {
  name         = "internal-service-key"
  value        = random_password.internal_key.result
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [azurerm_role_assignment.kv_admin]
}