variable "resource_group_name" {
  description = "Name of the Azure resource group for the staging environment."
  type        = string
}

variable "location" {
  description = "Azure region for the staging environment."
  type        = string
}

variable "app_service_plan_name" {
  description = "Name of the App Service plan for Platform.Api staging."
  type        = string
}

variable "web_app_name" {
  description = "Name of the Linux Web App for Platform.Api staging."
  type        = string
}

