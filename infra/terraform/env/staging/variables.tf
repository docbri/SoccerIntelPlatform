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

variable "databricks_workspace_name" {
  description = "Name of the Azure Databricks workspace for staging."
  type        = string
}

variable "databricks_workspace_sku" {
  description = "Azure Databricks workspace SKU for staging."
  type        = string
}

variable "databricks_location" {
  description = "Azure region for the staging Databricks resources."
  type        = string
}

variable "databricks_access_connector_name" {
  description = "Name of the Azure Databricks Access Connector for staging."
  type        = string
}

variable "databricks_managed_storage_account_name" {
  description = "Name of the ADLS Gen2 storage account for Unity Catalog managed storage."
  type        = string
}

variable "databricks_managed_storage_container_name" {
  description = "Name of the ADLS container for Unity Catalog managed storage."
  type        = string
}

variable "databricks_catalog_name" {
  description = "Unity Catalog catalog name for staging."
  type        = string
}

variable "databricks_bronze_schema_name" {
  description = "Unity Catalog bronze schema name for staging."
  type        = string
}

variable "databricks_silver_schema_name" {
  description = "Unity Catalog silver schema name for staging."
  type        = string
}

variable "databricks_gold_schema_name" {
  description = "Unity Catalog gold schema name for staging."
  type        = string
}
