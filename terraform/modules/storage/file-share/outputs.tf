output "storage_account_id" {
  description = "The resource ID of the created storage account."
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "The name of the created storage account."
  value       = azurerm_storage_account.main.name
}

output "primary_blob_endpoint" {
  description = "The primary Blob service endpoint for the storage account."
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "primary_file_endpoint" {
  description = "The primary File service endpoint for the storage account."
  value       = azurerm_storage_account.main.primary_file_endpoint
}

output "primary_access_key" {
  description = "The primary access key for the storage account."
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true # Marks the output as sensitive to prevent it from being shown in logs.
}