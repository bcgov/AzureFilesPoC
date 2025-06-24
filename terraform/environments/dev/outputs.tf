output "storage_account_name" {
  value = module.poc_storage_account.name
}

output "file_share_name" {
  value = module.poc_file_share.name
}

output "dev_vnet_addressSpace" {
  value = var.dev_vnet_addressSpace
}

output "dev_vnet_dnsServers" {
  value = var.dev_vnet_dnsServers
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
