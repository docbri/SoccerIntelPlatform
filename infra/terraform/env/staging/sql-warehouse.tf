resource "databricks_sql_endpoint" "platform_api" {
  name                      = var.databricks_sql_warehouse_name
  cluster_size              = var.databricks_sql_warehouse_cluster_size
  auto_stop_mins            = var.databricks_sql_warehouse_auto_stop_mins
  max_num_clusters          = 1
  warehouse_type            = "PRO"
  enable_serverless_compute = true
  no_wait                   = true

  tags {
    custom_tags {
      key   = "environment"
      value = "staging"
    }

    custom_tags {
      key   = "platform"
      value = "soccerintel"
    }

    custom_tags {
      key   = "managed_by"
      value = "opentofu"
    }

    custom_tags {
      key   = "workload"
      value = "platform-api-serving"
    }
  }
}
