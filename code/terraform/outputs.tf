output "dashboard_url" {
  description = "Static website URL for the monitoring dashboard"
  value       = module.storage.dashboard_url
}

output "api_endpoint" {
  description = "Function App API endpoint for the status API"
  value       = module.functions.api_endpoint
}

output "resource_group_name" {
  description = "Name of the main resource group"
  value       = azurerm_resource_group.main.name
}

output "function_app_name" {
  description = "Name of the deployed Function App"
  value       = module.functions.function_app_name
}

output "storage_account_name" {
  description = "Name of the monitoring Storage Account"
  value       = module.storage.account_name
}
