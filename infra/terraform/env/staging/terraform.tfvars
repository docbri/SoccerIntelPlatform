resource_group_name   = "rg-soccerintel-platform"
app_service_plan_name = "asp-soccerintel-platform"
web_app_name          = "app-soccerintel-platform-api"
location              = "eastus2"

databricks_workspace_name                 = "adb-soccerintel-staging"
databricks_workspace_sku                  = "premium"
databricks_location                       = "eastus2"
databricks_access_connector_name          = "ac-soccerintel-staging"
databricks_managed_storage_account_name   = "stsoccerinteldbstg"
databricks_managed_storage_container_name = "unity-catalog"

databricks_catalog_name       = "soccerintel_staging"
databricks_bronze_schema_name = "bronze"
databricks_silver_schema_name = "silver"
databricks_gold_schema_name   = "gold"

databricks_sql_warehouse_name           = "wh-soccerintel-staging-api"
databricks_sql_warehouse_cluster_size   = "2X-Small"
databricks_sql_warehouse_auto_stop_mins = 10
