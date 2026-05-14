output "logic_app_trigger_url" {
  description = "HTTP trigger callback URL — set as LOGIC_APP_TRIGGER_URL in Function App settings"
  value       = azurerm_logic_app_trigger_http_request.monitor.callback_url
  sensitive   = true
}

output "logic_app_name" {
  description = "Name of the Logic App workflow"
  value       = azurerm_logic_app_workflow.main.name
}
