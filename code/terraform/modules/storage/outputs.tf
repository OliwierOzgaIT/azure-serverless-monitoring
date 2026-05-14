output "account_name" {
  description = "Storage account name"
  value       = azurerm_storage_account.main.name
}

output "account_key" {
  description = "Primary access key"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "connection_string" {
  description = "Primary connection string"
  value       = azurerm_storage_account.main.primary_connection_string
  sensitive   = true
}

output "dashboard_url" {
  description = "Static website primary endpoint"
  value       = azurerm_storage_account.main.primary_web_endpoint
}

output "table_name" {
  description = "Table Storage table name"
  value       = azurerm_storage_table.results.name
}
