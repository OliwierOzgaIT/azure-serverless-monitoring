output "id" {
  description = "Key Vault resource ID"
  value       = azurerm_key_vault.main.id
}

output "uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

output "name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.main.name
}
