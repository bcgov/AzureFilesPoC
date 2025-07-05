# terraform/modules/storage/file-share/outputs.tf

output "id" {
  description = "The resource ID of the file share."
  value       = azurerm_storage_share.main.id
}

output "name" {
  description = "The name of the file share."
  value       = azurerm_storage_share.main.name
}

output "url" {
  description = "The URL of the file share."
  value       = azurerm_storage_share.main.url
}