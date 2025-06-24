output "storage_account_name" {
  value = module.poc_storage_account.name
}

output "file_share_name" {
  value = module.poc_file_share.name
}

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

output "dev_file_share_name" {
  value = var.dev_file_share_name
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
