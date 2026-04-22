resource "databricks_storage_credential" "access_connector" {
  name = "soccerintel-staging-credential"

  azure_managed_identity {
    access_connector_id = module.databricks_foundation.access_connector_id
  }

  comment = "Managed identity for Unity Catalog storage access"
}

resource "databricks_external_location" "managed_storage" {
  name            = "soccerintel-staging-storage"
  url             = module.databricks_foundation.managed_storage_url
  credential_name = databricks_storage_credential.access_connector.name

  comment = "External location for Unity Catalog managed storage"
}
