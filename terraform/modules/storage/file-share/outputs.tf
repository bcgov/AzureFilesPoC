output "id" {
  description = "The ID of the created file share."
  value       = azurerm_storage_share.main.id
}

output "name" {
  description = "The name of the created file share."
  value       = azurerm_storage_share.main.name
}

output "url" {
  description = "The URL of the created file share."
  value       = azurerm_storage_share.main.url
}
