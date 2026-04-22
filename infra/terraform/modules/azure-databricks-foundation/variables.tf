variable "workspace_name" {
  description = "Name of the Azure Databricks workspace."
  type        = string
}

variable "workspace_sku" {
  description = "Azure Databricks workspace SKU."
  type        = string
}

variable "access_connector_name" {
  description = "Name of the Azure Databricks Access Connector."
  type        = string
}

variable "managed_storage_account_name" {
  description = "Name of the ADLS Gen2 storage account used for Unity Catalog managed storage."
  type        = string
}

variable "managed_storage_container_name" {
  description = "Name of the ADLS container used for Unity Catalog managed storage."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group."
  type        = string
}

variable "location" {
  description = "Azure region for all Databricks foundation resources."
  type        = string
}

variable "tags" {
  description = "Tags to apply to Databricks foundation resources."
  type        = map(string)
  default     = {}
}

