provider "databricks" {
  host = module.databricks_foundation.workspace_url
}

