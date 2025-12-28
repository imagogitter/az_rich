# =============================================================================
# OUTPUTS
# =============================================================================

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.main.name
}

output "cosmos_account_name" {
  description = "Cosmos DB account name"
  value       = azurerm_cosmosdb_account.main.name
}

output "storage_account_name" {
  description = "Storage account name"
  value       = azurerm_storage_account.main.name
}

output "function_app_name" {
  description = "Function app name (to be created)"
  value       = local.function_app_name
}

output "apim_name" {
  description = "API Management name (to be created)"
  value       = local.apim_name
}

output "vmss_name" {
  description = "VM Scale Set name (to be created)"
  value       = local.vmss_name
}