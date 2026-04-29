terraform {
  required_version = ">= 1.7.0"

  backend "azurerm" {
    resource_group_name  = "rg-soccerintel-tfstate"
    storage_account_name = "soccerinteltfstate"
    container_name       = "tfstate"
    key                  = "soccerintel/staging/platform-api-v2.tfstate"

    use_azuread_auth = true
    use_oidc         = true
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "platform" {
  name     = var.resource_group_name
  location = var.location
}

module "app_service_plan" {
  source = "../../modules/app-service-plan"

  name                = var.app_service_plan_name
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
}

module "platform_api_web_app" {
  source = "../../modules/linux-web-app"

  name                = var.web_app_name
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  service_plan_id     = module.app_service_plan.id

  app_settings = {
    ASPNETCORE_ENVIRONMENT = "Staging"
  }
}

module "platform_api_staging_slot" {
  source = "../../modules/linux-web-app-slot"

  name           = "staging"
  app_service_id = module.platform_api_web_app.id

  app_settings = {
    ASPNETCORE_ENVIRONMENT = "Staging"
  }
}

module "redpanda_vm" {
  source = "../../modules/redpanda-vm"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location

  ssh_public_key_path = pathexpand("~/.ssh/id_rsa.pub")
}

module "databricks_foundation" {
  source = "../../modules/azure-databricks-foundation"

  workspace_name                 = var.databricks_workspace_name
  workspace_sku                  = var.databricks_workspace_sku
  access_connector_name          = var.databricks_access_connector_name
  managed_storage_account_name   = var.databricks_managed_storage_account_name
  managed_storage_container_name = var.databricks_managed_storage_container_name
  resource_group_name            = azurerm_resource_group.platform.name
  location                       = var.databricks_location

  tags = {
    environment = "staging"
    platform    = "soccerintel"
    managed_by  = "opentofu"
    workload    = "databricks-foundation"
  }
}

output "databricks_workspace_id" {
  value = module.databricks_foundation.workspace_id
}

output "databricks_workspace_name" {
  value = module.databricks_foundation.workspace_name
}

output "databricks_workspace_url" {
  value = module.databricks_foundation.workspace_url
}

output "databricks_access_connector_id" {
  value = module.databricks_foundation.access_connector_id
}

output "databricks_access_connector_principal_id" {
  value = module.databricks_foundation.access_connector_principal_id
}

output "databricks_managed_storage_account_id" {
  value = module.databricks_foundation.managed_storage_account_id
}

output "databricks_managed_storage_account_name" {
  value = module.databricks_foundation.managed_storage_account_name
}

output "databricks_managed_storage_container_name" {
  value = module.databricks_foundation.managed_storage_container_name
}

output "databricks_managed_storage_url" {
  value = module.databricks_foundation.managed_storage_url
}

output "databricks_catalog_name" {
  value = var.databricks_catalog_name
}

output "databricks_bronze_schema_name" {
  value = var.databricks_bronze_schema_name
}

output "databricks_silver_schema_name" {
  value = var.databricks_silver_schema_name
}

output "databricks_gold_schema_name" {
  value = var.databricks_gold_schema_name
}
