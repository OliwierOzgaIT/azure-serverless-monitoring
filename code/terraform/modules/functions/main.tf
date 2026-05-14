resource "azurerm_service_plan" "main" {
  name                = "asp-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "B1" # B1 - Available and cheap

  tags = var.tags
}

resource "azurerm_storage_account" "functions" {
  name                       = "stfunc${replace(var.project_name, "-", "")}${var.environment}"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  account_tier               = "Standard"
  account_replication_type   = "LRS"
  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"

  tags = var.tags
}

resource "azurerm_linux_function_app" "main" {
  name                       = "func-${var.project_name}-${var.environment}"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.main.id
  storage_account_name       = azurerm_storage_account.functions.name
  storage_account_access_key = azurerm_storage_account.functions.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }

    # Update to your dashboard_url output before applying
    cors {
      allowed_origins = ["https://stsitemonitordev.z6.web.core.windows.net"]
    }
    always_on = true
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"              = "python"
    "STORAGE_CONNECTION_STRING"             = "@Microsoft.KeyVault(VaultName=kv-${var.project_name}-${var.environment};SecretName=storage-connection-string)"
    "STORAGE_TABLE_NAME"                    = "monitoringresults"
    "SITES_TO_MONITOR"                      = join(",", var.sites_to_monitor)
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.main_t1.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main_t1.connection_string
  }

  tags = var.tags
}

resource "azurerm_key_vault_access_policy" "function_app" {
  key_vault_id       = var.keyvault_id
  tenant_id          = azurerm_linux_function_app.main.identity[0].tenant_id
  object_id          = azurerm_linux_function_app.main.identity[0].principal_id
  secret_permissions = ["Get", "List"]
  # Ensures Key Vault access policy exists before Function App starts
  depends_on = [azurerm_key_vault_access_policy.function_app]
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "main_t1" {
  name                = "appi-${var.project_name}-${var.environment}t1"
  resource_group_name = var.resource_group_name
  location            = var.location
  # Required — Classic App Insights deprecated in Azure 2024+
  workspace_id     = azurerm_log_analytics_workspace.main.id
  application_type = "web"
  tags             = var.tags
}
