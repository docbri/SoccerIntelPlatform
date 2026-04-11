resource "azurerm_linux_web_app_slot" "this" {
  name           = var.name
  app_service_id = var.app_service_id

  site_config {
    application_stack {
      dotnet_version = "10.0"
    }
  }

  app_settings = var.app_settings
}

