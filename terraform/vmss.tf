# =============================================================================
# VIRTUAL MACHINE SCALE SET (A100 GPU)
# =============================================================================

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = local.vnet_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
  
  tags = local.tags
}

# Subnet for VMSS
resource "azurerm_subnet" "vmss" {
  name                 = "${var.project_name}-vmss-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group for VMSS
resource "azurerm_network_security_group" "vmss" {
  name                = "${var.project_name}-vmss-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Allow SSH (for management)
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Allow HTTP inference API
  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  tags = local.tags
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "vmss" {
  subnet_id                 = azurerm_subnet.vmss.id
  network_security_group_id = azurerm_network_security_group.vmss.id
}

# Public IP for load balancer
resource "azurerm_public_ip" "vmss_lb" {
  name                = "${var.project_name}-vmss-lb-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = local.tags
}

# Load Balancer for VMSS
resource "azurerm_lb" "vmss" {
  name                = "${var.project_name}-vmss-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.vmss_lb.id
  }
  
  tags = local.tags
}

# Backend address pool
resource "azurerm_lb_backend_address_pool" "vmss" {
  loadbalancer_id = azurerm_lb.vmss.id
  name            = "BackendPool"
}

# Health probe
resource "azurerm_lb_probe" "vmss" {
  loadbalancer_id = azurerm_lb.vmss.id
  name            = "http-health-probe"
  protocol        = "Http"
  port            = 8000
  request_path    = "/health"
}

# Load balancing rule
resource "azurerm_lb_rule" "vmss" {
  loadbalancer_id                = azurerm_lb.vmss.id
  name                           = "HTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 8000
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.vmss.id]
  probe_id                       = azurerm_lb_probe.vmss.id
  disable_outbound_snat          = true
}

# Outbound rule for internet access
resource "azurerm_lb_outbound_rule" "vmss" {
  name                    = "OutboundRule"
  loadbalancer_id         = azurerm_lb.vmss.id
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.vmss.id
  
  frontend_ip_configuration {
    name = "PublicIPAddress"
  }
}

# Generate SSH key for VMSS
resource "tls_private_key" "vmss_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store SSH private key in Key Vault
resource "azurerm_key_vault_secret" "vmss_ssh_private_key" {
  name         = "vmss-ssh-private-key"
  value        = tls_private_key.vmss_ssh.private_key_pem
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [azurerm_role_assignment.kv_admin]
}

# Linux Virtual Machine Scale Set with A100 GPUs
resource "azurerm_linux_virtual_machine_scale_set" "gpu" {
  name                = local.vmss_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = var.vmss_sku
  instances           = var.vmss_min_instances
  admin_username      = "azureuser"
  
  # Spot instance configuration for cost savings
  priority        = "Spot"
  eviction_policy = "Deallocate"
  max_bid_price   = var.vmss_spot_max_price
  
  # Scale to zero for $0 idle cost
  overprovision = false
  
  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.vmss_ssh.public_key_openssh
  }
  
  source_image_reference {
    publisher = "microsoft-dsvm"
    offer     = "ubuntu-hpc"
    sku       = "2004"
    version   = "latest"
  }
  
  os_disk {
    storage_account_type = "Premium_LRS"
    caching              = "ReadWrite"
    disk_size_gb         = 128
  }
  
  network_interface {
    name    = "vmss-nic"
    primary = true
    
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.vmss.id
      
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.vmss.id]
    }
    
    enable_accelerated_networking = true
  }
  
  # Custom data for GPU setup
  custom_data = base64encode(templatefile("${path.module}/scripts/gpu-setup.sh", {
    key_vault_name = azurerm_key_vault.main.name
  }))
  
  sensitive = true  # Mark as sensitive since custom_data may contain configuration
  
  # Enable automatic OS upgrades
  automatic_os_upgrade_policy {
    disable_automatic_rollback  = false
    enable_automatic_os_upgrade = true
  }
  
  # Rolling upgrade policy
  rolling_upgrade_policy {
    max_batch_instance_percent              = 20
    max_unhealthy_instance_percent          = 20
    max_unhealthy_upgraded_instance_percent = 20
    pause_time_between_batches              = "PT0S"
  }
  
  # Health probe
  health_probe_id = azurerm_lb_probe.vmss.id
  
  # Identity for Key Vault access
  identity {
    type = "SystemAssigned"
  }
  
  # Lifecycle to prevent accidental deletion
  lifecycle {
    ignore_changes = [instances]
  }
  
  tags = local.tags
  
  depends_on = [
    azurerm_lb_rule.vmss,
    azurerm_subnet_network_security_group_association.vmss
  ]
}

# Grant VMSS managed identity access to Key Vault
resource "azurerm_role_assignment" "vmss_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine_scale_set.gpu.identity[0].principal_id
}

# =============================================================================
# AUTOSCALING CONFIGURATION
# =============================================================================

resource "azurerm_monitor_autoscale_setting" "vmss" {
  name                = "${var.project_name}-vmss-autoscale"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.gpu.id
  
  profile {
    name = "defaultProfile"
    
    capacity {
      default = var.vmss_min_instances
      minimum = var.vmss_min_instances
      maximum = var.vmss_max_instances
    }
    
    # Scale out rule - increase instances when CPU > 70%
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.gpu.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }
      
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
    
    # Scale in rule - decrease instances when CPU < 30%
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.gpu.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }
      
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
  
  # Scale based on schedule (optional - scale to 0 during off-hours)
  # Only enabled when enable_weekend_scale_to_zero is true
  dynamic "profile" {
    for_each = var.enable_weekend_scale_to_zero ? [1] : []
    
    content {
      name = "offHoursProfile"
      
      capacity {
        default = 0
        minimum = 0
        maximum = var.vmss_max_instances
      }
      
      # Scale to 0 on weekends (Saturday and Sunday)
      recurrence {
        timezone = "UTC"
        days     = ["Saturday", "Sunday"]
        hours    = [0]
        minutes  = [0]
      }
    }
  }
  
  notification {
    email {
      send_to_subscription_administrator    = false
      send_to_subscription_co_administrator = false
      custom_emails                         = [var.admin_email]
    }
  }
  
  tags = local.tags
}
