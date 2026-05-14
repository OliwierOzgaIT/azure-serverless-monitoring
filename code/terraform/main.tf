terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    # These values are specific to this deployment.
    # When forking this project, create your own storage account for remote state
    # and update these values accordingly. See README Step 1 — Bootstrap Remote State.
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateoozga2026"
    container_name       = "tfstateoozga2026"
    key                  = "monitoring.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = local.common_tags
}

module "storage" {
  source              = "./modules/storage"
  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

module "keyvault" {
  source                    = "./modules/keyvault"
  project_name              = var.project_name
  environment               = var.environment
  location                  = var.location
  resource_group_name       = azurerm_resource_group.main.name
  tags                      = local.common_tags
  storage_connection_string = module.storage.connection_string
}

module "functions" {
  source               = "./modules/functions"
  project_name         = var.project_name
  environment          = var.environment
  location             = var.location
  resource_group_name  = azurerm_resource_group.main.name
  tags                 = local.common_tags
  keyvault_id          = module.keyvault.id
  keyvault_uri         = module.keyvault.uri
  keyvault_name        = module.keyvault.name
  storage_account_name = module.storage.account_name
  storage_account_key  = module.storage.account_key
  sites_to_monitor     = var.sites_to_monitor
}

module "alerting" {
  source              = "./modules/alerting"
  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
  function_app_id     = module.functions.function_app_id
  alert_email         = var.alert_email
}
