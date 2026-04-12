
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

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

