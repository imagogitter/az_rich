# =============================================================================
# OUTPUTS
# =============================================================================

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Azure region where resources are deployed"
  value       = azurerm_resource_group.main.location
}

# Key Vault outputs
output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

# Storage outputs
output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "storage_account_primary_connection_string" {
  description = "Primary connection string for storage account"
  value       = azurerm_storage_account.main.primary_connection_string
  sensitive   = true
}

# Cosmos DB outputs
output "cosmos_account_name" {
  description = "Name of the Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.name
}

output "cosmos_endpoint" {
  description = "Endpoint URL for Cosmos DB"
  value       = azurerm_cosmosdb_account.main.endpoint
}

output "cosmos_primary_key" {
  description = "Primary key for Cosmos DB"
  value       = azurerm_cosmosdb_account.main.primary_key
  sensitive   = true
}

# Function App outputs
output "function_app_name" {
  description = "Name of the Function App"
  value       = azurerm_linux_function_app.main.name
}

output "function_app_url" {
  description = "URL of the Function App"
  value       = "https://${azurerm_linux_function_app.main.default_hostname}"
}

output "function_app_identity_principal_id" {
  description = "Principal ID of Function App managed identity"
  value       = azurerm_linux_function_app.main.identity[0].principal_id
}

# VMSS outputs
output "vmss_name" {
  description = "Name of the VM Scale Set"
  value       = azurerm_linux_virtual_machine_scale_set.gpu.name
}

output "vmss_public_ip" {
  description = "Public IP address of the VMSS load balancer"
  value       = azurerm_public_ip.vmss.ip_address
}

output "vmss_identity_principal_id" {
  description = "Principal ID of VMSS managed identity"
  value       = azurerm_linux_virtual_machine_scale_set.gpu.identity[0].principal_id
}

# API Management outputs
output "apim_name" {
  description = "Name of the API Management instance"
  value       = azurerm_api_management.main.name
}

output "apim_gateway_url" {
  description = "Gateway URL for API Management"
  value       = azurerm_api_management.main.gateway_url
}

output "apim_inference_api_path" {
  description = "Full path to the inference API"
  value       = "${azurerm_api_management.main.gateway_url}/inference"
}

# Networking outputs
output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}

# Monitoring outputs
output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "application_insights_name" {
  description = "Name of the Application Insights instance"
  value       = azurerm_application_insights.main.name
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

# Summary output
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    resource_group    = azurerm_resource_group.main.name
    location          = azurerm_resource_group.main.location
    key_vault         = azurerm_key_vault.main.name
    storage_account   = azurerm_storage_account.main.name
    cosmos_db         = azurerm_cosmosdb_account.main.name
    function_app      = azurerm_linux_function_app.main.name
    vmss              = azurerm_linux_virtual_machine_scale_set.gpu.name
    apim              = azurerm_api_management.main.name
    vnet              = azurerm_virtual_network.main.name
    log_analytics     = azurerm_log_analytics_workspace.main.name
    app_insights      = azurerm_application_insights.main.name
    api_endpoint      = "${azurerm_api_management.main.gateway_url}/inference"
  }
}
