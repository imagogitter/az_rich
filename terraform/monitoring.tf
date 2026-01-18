# =============================================================================
# MONITORING & ALERTS
# =============================================================================

# Application Insights alerts
resource "azurerm_monitor_metric_alert" "function_failures" {
  name                = "function-failures"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Alert when function execution failures exceed threshold"

  criteria {
    metric_namespace = "Microsoft.Insights/Components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 5

    dimension {
      name     = "request/resultCode"
      operator = "Include"
      values   = ["500", "502", "503"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

resource "azurerm_monitor_metric_alert" "high_response_time" {
  name                = "high-response-time"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Alert when average response time exceeds 30 seconds"

  criteria {
    metric_namespace = "Microsoft.Insights/Components"
    metric_name      = "requests/duration"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 30000  # 30 seconds
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# VMSS alerts
resource "azurerm_monitor_metric_alert" "vmss_cpu_high" {
  name                = "vmss-cpu-high"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_virtual_machine_scale_set.gpu.id]
  description         = "Alert when VMSS CPU usage is consistently high"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachineScaleSets"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Cosmos DB alerts
resource "azurerm_monitor_metric_alert" "cosmos_throttling" {
  name                = "cosmos-throttling"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_cosmosdb_account.main.id]
  description         = "Alert when Cosmos DB requests are being throttled"

  criteria {
    metric_namespace = "Microsoft.DocumentDB/databaseAccounts"
    metric_name      = "TotalRequests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 1000

    dimension {
      name     = "StatusCode"
      operator = "Include"
      values   = ["429"]  # Throttled requests
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Action Group for alerts
resource "azurerm_monitor_action_group" "main" {
  name                = "${var.project_name}-alerts"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "AIAlerts"

  email_receiver {
    name          = "admin"
    email_address = var.admin_email
  }

  # Could add webhook, SMS, etc.
}

# Log Analytics alerts
resource "azurerm_monitor_scheduled_query_rules_alert" "function_errors" {
  name                = "function-errors-log"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  action {
    action_group = [azurerm_monitor_action_group.main.id]
  }

  data_source_id = azurerm_log_analytics_workspace.main.id

  description = "Alert on function execution errors in logs"
  enabled     = true

  query = <<-QUERY
    AzureFunctionsLogs_CL
    | where Level_s == "Error"
    | where Message_s contains "failed" or Message_s contains "exception"
    | summarize Count = count() by bin(TimeGenerated, 5m)
    | where Count > 10
  QUERY

  severity    = 2
  frequency   = 5
  time_window = 5

  trigger {
    operator  = "GreaterThan"
    threshold = 10
  }
}