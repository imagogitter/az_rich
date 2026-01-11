# =============================================================================
# VM SCALE SET (GPU Instances with Spot Priority)
# =============================================================================

# Public IP for VMSS load balancer
resource "azurerm_public_ip" "vmss" {
  name                = "${local.vmss_name}-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = local.tags
}

# Load Balancer for VMSS
resource "azurerm_lb" "vmss" {
  name                = "${local.vmss_name}-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.vmss.id
  }
  
  tags = local.tags
}

# Backend pool for load balancer
resource "azurerm_lb_backend_address_pool" "vmss" {
  name            = "vmss-backend-pool"
  loadbalancer_id = azurerm_lb.vmss.id
}

# Load balancer health probe
resource "azurerm_lb_probe" "vmss" {
  name            = "health-probe"
  loadbalancer_id = azurerm_lb.vmss.id
  protocol        = "Http"
  port            = 80
  request_path    = "/health"
}

# Load balancer rule
resource "azurerm_lb_rule" "vmss" {
  name                           = "http"
  loadbalancer_id                = azurerm_lb.vmss.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.vmss.id]
  probe_id                       = azurerm_lb_probe.vmss.id
}

# VM Scale Set with Spot instances
resource "azurerm_linux_virtual_machine_scale_set" "gpu" {
  name                = local.vmss_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = var.vmss_sku
  instances           = var.vmss_min_instances
  admin_username      = "azureuser"
  admin_password      = "P@ssw0rd1234!" # Change this in production or use SSH keys
  priority            = "Spot"
  eviction_policy     = "Deallocate"
  max_bid_price       = var.vmss_spot_max_price
  
  # Note: Generate SSH key before deploying: ssh-keygen -t rsa -b 4096 -f terraform/ssh_key -N ""
  # Or set disable_password_authentication = false and provide admin_password instead
  disable_password_authentication = false
  
  # Uncomment when SSH key is available:
  # admin_ssh_key {
  #   username   = "azureuser"
  #   public_key = file("${path.module}/ssh_key.pub")
  # }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  
  network_interface {
    name    = "vmss-nic"
    primary = true
    
    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.vmss.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.vmss.id]
    }
  }
  
  # Custom script extension for GPU driver installation
  extension {
    name                       = "gpu-drivers"
    publisher                  = "Microsoft.Azure.Extensions"
    type                       = "CustomScript"
    type_handler_version       = "2.1"
    auto_upgrade_minor_version = true
    
    settings = jsonencode({
      "commandToExecute" = "apt-get update && apt-get install -y nvidia-driver-535 && systemctl restart nvidia-persistenced"
    })
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = local.tags
}

# Auto-scale settings for VMSS
resource "azurerm_monitor_autoscale_setting" "vmss" {
  name                = "${local.vmss_name}-autoscale"
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
    
    # Scale out rule (based on CPU)
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
        value     = "2"
        cooldown  = "PT5M"
      }
    }
    
    # Scale in rule (based on CPU)
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.gpu.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
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
  
  tags = local.tags
}
