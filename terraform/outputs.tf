# =============================================================================
# OUTPUTS
# =============================================================================

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Azure region"
  value       = azurerm_resource_group.main.location
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "vmss_name" {
  description = "Name of the Virtual Machine Scale Set"
  value       = azurerm_linux_virtual_machine_scale_set.gpu.name
}

output "vmss_id" {
  description = "ID of the Virtual Machine Scale Set"
  value       = azurerm_linux_virtual_machine_scale_set.gpu.id
}

output "vmss_sku" {
  description = "VM SKU used for the scale set"
  value       = var.vmss_sku
}

output "vmss_min_instances" {
  description = "Minimum number of instances (set to 0 for $0 idle cost)"
  value       = var.vmss_min_instances
}

output "vmss_max_instances" {
  description = "Maximum number of instances"
  value       = var.vmss_max_instances
}

output "load_balancer_public_ip" {
  description = "Public IP address of the load balancer"
  value       = azurerm_public_ip.vmss_lb.ip_address
}

output "load_balancer_fqdn" {
  description = "FQDN of the load balancer public IP"
  value       = azurerm_public_ip.vmss_lb.fqdn
}

output "autoscale_setting_id" {
  description = "ID of the autoscale setting"
  value       = azurerm_monitor_autoscale_setting.vmss.id
}

output "ssh_private_key_secret_name" {
  description = "Name of the SSH private key secret in Key Vault"
  value       = azurerm_key_vault_secret.vmss_ssh_private_key.name
}

output "deployment_instructions" {
  description = "Instructions for accessing the deployment"
  value = <<-EOT
    
    ╔════════════════════════════════════════════════════════════════════════════╗
    ║                    A100 GPU VMSS DEPLOYMENT COMPLETE                       ║
    ╚════════════════════════════════════════════════════════════════════════════╝
    
    Resource Group:   ${azurerm_resource_group.main.name}
    Location:         ${azurerm_resource_group.main.location}
    VM SKU:           ${var.vmss_sku} (8x NVIDIA A100 GPUs per instance)
    
    Scale Configuration:
    - Minimum instances: ${var.vmss_min_instances} (for $0 idle cost)
    - Maximum instances: ${var.vmss_max_instances}
    - Current instances: Managed by autoscaler
    
    Load Balancer:
    - Public IP: ${azurerm_public_ip.vmss_lb.ip_address}
    - Health endpoint: http://${azurerm_public_ip.vmss_lb.ip_address}/health
    - Inference endpoint: http://${azurerm_public_ip.vmss_lb.ip_address}/inference
    
    Key Vault:
    - Name: ${azurerm_key_vault.main.name}
    - SSH Key: ${azurerm_key_vault_secret.vmss_ssh_private_key.name}
    
    Autoscaling:
    - Scales UP when CPU > 70% (checked every 5 minutes)
    - Scales DOWN when CPU < 30% (checked every 10 minutes)
    - Scales to 0 on weekends (optional schedule)
    
    Cost Optimization:
    ✓ Spot instances enabled (up to 90% discount)
    ✓ Scales to ${var.vmss_min_instances} when idle ($0 compute cost)
    ✓ Fast spin-up with pre-configured GPU image
    
    Next Steps:
    1. Test health endpoint: curl http://${azurerm_public_ip.vmss_lb.ip_address}/health
    2. Monitor autoscaling: az monitor autoscale show --name ${local.vmss_name}-vmss-autoscale --resource-group ${azurerm_resource_group.main.name}
    3. Scale manually if needed: az vmss scale --name ${azurerm_linux_virtual_machine_scale_set.gpu.name} --new-capacity <N> --resource-group ${azurerm_resource_group.main.name}
    4. View logs: az vmss get-instance-view --name ${azurerm_linux_virtual_machine_scale_set.gpu.name} --resource-group ${azurerm_resource_group.main.name}
    
    To SSH to instances:
    1. Get SSH key: az keyvault secret show --vault-name ${azurerm_key_vault.main.name} --name ${azurerm_key_vault_secret.vmss_ssh_private_key.name} --query value -o tsv > ~/.ssh/vmss_key.pem
    2. chmod 600 ~/.ssh/vmss_key.pem
    3. Get instance IP and SSH: ssh -i ~/.ssh/vmss_key.pem azureuser@<instance-ip>
    
  EOT
}
