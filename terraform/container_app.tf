# =============================================================================
# AZURE CONTAINER REGISTRY FOR FRONTEND
# =============================================================================

resource "azurerm_container_registry" "frontend" {
  name                = "${replace(var.project_name, "-", "")}acr${local.name_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = local.tags
}

# =============================================================================
# AZURE CONTAINER APP ENVIRONMENT
# =============================================================================

resource "azurerm_log_analytics_workspace" "container_apps" {
  name                = "${var.project_name}-ca-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.tags
}

resource "azurerm_container_app_environment" "main" {
  name                       = "${var.project_name}-env"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.container_apps.id

  tags = local.tags
}

# =============================================================================
# AZURE CONTAINER APP FOR OPEN WEBUI FRONTEND
# =============================================================================

resource "azurerm_container_app" "frontend" {
  name                         = "${var.project_name}-frontend"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  # Registry configuration
  registry {
    server               = azurerm_container_registry.frontend.login_server
    username             = azurerm_container_registry.frontend.admin_username
    password_secret_name = "registry-password"
  }

  # Secrets
  secret {
    name  = "registry-password"
    value = azurerm_container_registry.frontend.admin_password
  }

  secret {
    name  = "openai-api-key"
    value = random_password.frontend_api_key.result
  }

  template {
    container {
      name   = "open-webui"
      image  = "${azurerm_container_registry.frontend.login_server}/open-webui:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "OPENAI_API_BASE_URL"
        value = "https://${azurerm_linux_function_app.main.default_hostname}/api/v1"
      }

      env {
        name        = "OPENAI_API_KEY"
        secret_name = "openai-api-key"
      }

      env {
        name  = "WEBUI_AUTH"
        value = "true"
      }

      env {
        name  = "ENABLE_SIGNUP"
        value = "false"
      }

      env {
        name  = "WEBUI_NAME"
        value = "AI Inference Platform"
      }

      env {
        name  = "DEFAULT_USER_ROLE"
        value = "user"
      }

      env {
        name  = "PORT"
        value = "8080"
      }
    }

    min_replicas = 0
    max_replicas = 3
  }

  ingress {
    external_enabled = true
    target_port      = 8080

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = local.tags
}

# =============================================================================
# RANDOM PASSWORD FOR FRONTEND API KEY
# =============================================================================

resource "random_password" "frontend_api_key" {
  length  = 32
  special = true
}

# Store API key in Key Vault
resource "azurerm_key_vault_secret" "frontend_api_key" {
  name         = "frontend-openai-api-key"
  value        = random_password.frontend_api_key.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.kv_admin]
}
