# =============================================================================
# API MANAGEMENT
# =============================================================================

resource "azurerm_api_management" "main" {
  name                = local.apim_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = "AI Inference Platform"
  publisher_email     = var.admin_email

  sku_name = "Consumption_0"

  virtual_network_type = "None"

  tags = local.tags
}

resource "azurerm_api_management_api" "chat_completions" {
  name                = "chat-completions"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "Chat Completions API"
  path                = "v1"
  protocols           = ["https"]

  subscription_required = false

  service_url = "https://${azurerm_function_app.main.default_hostname}/api"

  import_openapi_specification {
    content_format = "openapi+json"
    content_value  = file("${path.module}/../openapi.json")
  }
}

resource "azurerm_api_management_api_policy" "chat_completions" {
  api_name            = azurerm_api_management_api.chat_completions.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name

  xml_content = <<XML
<policies>
    <inbound>
        <rate-limit calls="100" renewal-period="60" />
        <set-header name="X-Request-ID" exists-action="skip">
            <value>@(Guid.NewGuid().ToString())</value>
        </set-header>
        <cors>
            <allowed-origins>
                <origin>*</origin>
            </allowed-origins>
            <allowed-methods>
                <method>POST</method>
                <method>GET</method>
            </allowed-methods>
            <allowed-headers>
                <header>*</header>
            </allowed-headers>
        </cors>
    </inbound>
    <backend>
        <forward-request />
    </backend>
    <outbound>
        <set-header name="X-API-Source" exists-action="override">
            <value>ai-inference-platform</value>
        </set-header>
    </outbound>
</policies>
XML
}

resource "azurerm_api_management_api" "models" {
  name                = "models"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "Models API"
  path                = "v1"
  protocols           = ["https"]

  subscription_required = false

  service_url = "https://${azurerm_function_app.main.default_hostname}/api"

  import_openapi_specification {
    content_format = "openapi+json"
    content_value  = file("${path.module}/../openapi.json")
  }
}

resource "azurerm_api_management_api" "health" {
  name                = "health"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "Health API"
  path                = "health"
  protocols           = ["https"]

  subscription_required = false

  service_url = "https://${azurerm_function_app.main.default_hostname}/api"

  import_openapi_specification {
    content_format = "openapi+json"
    content_value  = file("${path.module}/../openapi.json")
  }
}