output "id" {
  description = "The ID of the storage container"
  value       = azapi_resource.blob_container.id
}

output "name" {
  description = "The name of the storage container"
  value       = azapi_resource.blob_container.name
}

output "storage_account_name" {
  description = "The name of the storage account"
  value       = var.storage_account_name
}

output "container_access_type" {
  description = "The access type of the container"
  value       = var.container_access_type
}