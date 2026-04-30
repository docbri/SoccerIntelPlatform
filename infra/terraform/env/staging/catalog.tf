resource "databricks_catalog" "soccerintel" {
  name          = var.databricks_catalog_name
  comment       = "SoccerIntelPlatform staging catalog"
  force_destroy = true

  storage_root = databricks_external_location.managed_storage.url
}

