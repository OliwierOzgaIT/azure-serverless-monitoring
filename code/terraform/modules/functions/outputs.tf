output "function_app_name" {
  description = "Name of the Function App"
  value       = azurerm_linux_function_app.main.name
}

output "function_app_id" {
  description = "Resource ID of the Function App"
  value       = azurerm_linux_function_app.main.id
}

output "api_endpoint" {
  description = "Full URL of the status API function"
  value       = "https://${azurerm_linux_function_app.main.default_hostname}/api/api"
}
