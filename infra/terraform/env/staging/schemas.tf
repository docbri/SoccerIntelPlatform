resource "databricks_schema" "bronze" {
  name         = var.databricks_bronze_schema_name
  catalog_name = databricks_catalog.soccerintel.name
  comment      = "Bronze layer - raw ingestion"
}

resource "databricks_schema" "silver" {
  name         = var.databricks_silver_schema_name
  catalog_name = databricks_catalog.soccerintel.name
  comment      = "Silver layer - cleaned and validated"
}

resource "databricks_schema" "gold" {
  name         = var.databricks_gold_schema_name
  catalog_name = databricks_catalog.soccerintel.name
  comment      = "Gold layer - serving layer"
}

