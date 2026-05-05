output "redpanda_public_ip" {
  value = module.redpanda_vm.redpanda_public_ip
}

output "databricks_sql_warehouse_id" {
  value = databricks_sql_endpoint.platform_api.id
}
