output "workspace_id" {
  description = "ID of the Azure Databricks workspace."
  value       = azurerm_databricks_workspace.this.id
}

output "workspace_name" {
  description = "Name of the Azure Databricks workspace."
  value       = azurerm_databricks_workspace.this.name
}

output "workspace_url" {
  description = "Workspace URL for Azure Databricks."
  value       = azurerm_databricks_workspace.this.workspace_url
}

output "access_connector_id" {
  description = "ID of the Azure Databricks Access Connector."
  value       = azurerm_databricks_access_connector.this.id
}

output "access_connector_principal_id" {
  description = "Principal ID of the system-assigned managed identity on the Access Connector."
  value       = azurerm_databricks_access_connector.this.identity[0].principal_id
}

output "managed_storage_account_id" {
  description = "ID of the ADLS Gen2 storage account."
  value       = azurerm_storage_account.this.id
}

output "managed_storage_account_name" {
  description = "Name of the ADLS Gen2 storage account."
  value       = azurerm_storage_account.this.name
}

output "managed_storage_container_name" {
  description = "Name of the ADLS Gen2 container."
  value       = azurerm_storage_container.this.name
}

output "managed_storage_url" {
  description = "ABFSS URL for the Unity Catalog managed storage container."
  value       = "abfss://${azurerm_storage_container.this.name}@${azurerm_storage_account.this.name}.dfs.core.windows.net/"
}

