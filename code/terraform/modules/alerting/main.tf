resource "azurerm_logic_app_workflow" "main" {
  name                = "logic-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_logic_app_trigger_http_request" "monitor" {
  name         = "site-down-trigger"
  logic_app_id = azurerm_logic_app_workflow.main.id

  schema = jsonencode({
    type = "object"
    properties = {
      site_url      = { type = "string" }
      status_code   = { type = "integer" }
      response_time = { type = "number" }
      checked_at    = { type = "string" }
      error_message = { type = "string" }
    }
  })
}

resource "azurerm_logic_app_action_http" "notify" {
  name         = "send-email-placeholder"
  logic_app_id = azurerm_logic_app_workflow.main.id
  method       = "POST"
  uri          = "https://placeholder.example.com/notify"

  body = jsonencode({
    alert_email   = var.alert_email
    site_url      = "@{triggerBody()?['site_url']}"
    status_code   = "@{triggerBody()?['status_code']}"
    response_time = "@{triggerBody()?['response_time']}"
    checked_at    = "@{triggerBody()?['checked_at']}"
    error_message = "@{triggerBody()?['error_message']}"
  })
}
