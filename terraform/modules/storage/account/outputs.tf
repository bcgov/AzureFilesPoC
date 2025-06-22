output "id" {
  description = "The ID of the created storage account."
  value       = azurerm_storage_account.main.id
}

output "name" {
  description = "The name of the created storage account."
  value       = azurerm_storage_account.main.name
}

output "primary_blob_host" {
  description = "The primary blob endpoint host."
  value       = azurerm_storage_account.main.primary_blob_host
}