# =============================================================================
# API MANAGEMENT
# =============================================================================

resource "azurerm_api_management" "main" {
  name                = local.apim_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = var.project_name
  publisher_email     = var.admin_email
  sku_name            = "Consumption_0"

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

# API Management Logger (Application Insights)
resource "azurerm_api_management_logger" "app_insights" {
  name                = "app-insights-logger"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  resource_id         = azurerm_application_insights.main.id

  application_insights {
    instrumentation_key = azurerm_application_insights.main.instrumentation_key
  }
}

# API for inference endpoints
resource "azurerm_api_management_api" "inference" {
  name                = "inference-api"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "AI Inference API"
  path                = "inference"
  protocols           = ["https"]

  subscription_required = true
}

# API operation: Health check
resource "azurerm_api_management_api_operation" "health" {
  operation_id        = "health-check"
  api_name            = azurerm_api_management_api.inference.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "Health Check"
  method              = "GET"
  url_template        = "/health"

  response {
    status_code = 200
    description = "Success"
  }
}

# API operation: List models
resource "azurerm_api_management_api_operation" "list_models" {
  operation_id        = "list-models"
  api_name            = azurerm_api_management_api.inference.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "List Available Models"
  method              = "GET"
  url_template        = "/models"

  response {
    status_code = 200
    description = "Success"
  }
}

# API operation: Generate completion
resource "azurerm_api_management_api_operation" "completions" {
  operation_id        = "generate-completion"
  api_name            = azurerm_api_management_api.inference.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "Generate Completion"
  method              = "POST"
  url_template        = "/completions"

  request {
    description = "Completion request"
  }

  response {
    status_code = 200
    description = "Success"
  }
}

# Backend for Function App
resource "azurerm_api_management_backend" "function_app" {
  name                = "function-backend"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = "https://${azurerm_linux_function_app.main.default_hostname}/api"

  credentials {
    header = {
      "x-functions-key" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=internal-service-key)"
    }
  }
}

# Policy to route to Function App backend
resource "azurerm_api_management_api_policy" "inference" {
  api_name            = azurerm_api_management_api.inference.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="${azurerm_api_management_backend.function_app.name}" />
    <rate-limit calls="1000" renewal-period="60" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

# Grant API Management access to Key Vault
resource "azurerm_role_assignment" "apim_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_api_management.main.identity[0].principal_id
}
