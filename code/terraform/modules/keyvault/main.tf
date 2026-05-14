data "azurerm_client_config" "current" {}

locals {
  # substr keeps name within Azure's 24-character Key Vault limit
  kv_name = "kv-${substr(replace(var.project_name, "-", ""), 0, 12)}-${var.environment}"
}

resource "azurerm_key_vault" "main" {
  name                       = local.kv_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = ["Get", "Set", "Delete", "List", "Purge", "Recover"]
  }

  tags = var.tags
}

resource "azurerm_key_vault_secret" "storage_connection" {
  name         = "storage-connection-string"
  value        = var.storage_connection_string
  key_vault_id = azurerm_key_vault.main.id
}
