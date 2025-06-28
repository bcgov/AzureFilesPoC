# output "dev_storage_account_name" {
#   value = module.poc_storage_account.name
# }

# output "dev_file_share_name" {
#   value = module.poc_file_share.name
# }

output "dev_vnet_address_space" {
  value = var.dev_vnet_address_space
}

output "dev_vnet_dns_servers" {
  value = var.dev_vnet_dns_servers
}

output "dev_vnet_id" {
  value = var.dev_vnet_id
}

output "dev_resource_id" {
  value = var.dev_resource_id
}

output "dev_file_share_quota_gb" {
  value = var.dev_file_share_quota_gb
}

output "dev_network_security_group" {
  value = var.dev_network_security_group
}

output "dev_dns_servers" {
  value = var.dev_dns_servers
}

# output "dev_resource_group_name" {
#   value = module.poc_resource_group.resource_group_name
# }

# output "dev_resource_group_location" {
#   value = module.poc_resource_group.resource_group_location
# }

# output "dev_resource_group_id" {
#   value = module.poc_resource_group.resource_group_id
# }

# output "dev_storage_account_id" {
#   value = module.poc_storage_account.id
# }

# output "dev_storage_account_name" {
#   value = module.poc_storage_account.name
# }

# output "dev_storage_account_primary_blob_host" {
#   value = module.poc_storage_account.primary_blob_host
# }

output "debug_service_principal_id" {
  value = var.service_principal_id
}

output "dev_service_principal_id" {
  value       = var.dev_service_principal_id
  description = "The object ID of the service principal used for role assignments."
}

# output "file_sync_service_id" {
#   value = module.file_sync.id
# }
# output "file_sync_service_name" {
#   value = module.file_sync.name
# }
# output "log_analytics_workspace_id" {
#   value = module.monitoring.id
# }
# output "log_analytics_workspace_name" {
#   value = module.monitoring.name
# }
# output "automation_account_id" {
#   value = module.automation.id
# }
# output "automation_account_name" {
#   value = module.automation.name
# }
# output "firewall_id" {
#   value = module.firewall.id
# }
# output "firewall_name" {
#   value = module.firewall.name
# }
# output "route_table_id" {
#   value = module.route_table.id
# }
# output "route_table_name" {
#   value = module.route_table.name
# }
# output "vnet_gateway_id" {
#   value = module.vnet_gateway.id
# }
# output "vnet_gateway_name" {
#   value = module.vnet_gateway.name
# }
# output "blob_container_id" {
#   value = module.poc_blob_container.id
# }
# output "blob_container_name" {
#   value = module.poc_blob_container.name
# }
# output "storage_management_policy_id" {
#   value = module.poc_storage_management_policy.id
# }
# output "private_dns_zone_id" {
#   value = module.private_dns_zone.id
# }
# output "private_dns_zone_name" {
#   value = module.private_dns_zone.name
# }
