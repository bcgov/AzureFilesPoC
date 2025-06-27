output "id" {
  description = "The ID of the blob container."
  value       = azurerm_storage_container.main.id
}

output "name" {
  description = "The name of the blob container."
  value       = azurerm_storage_container.main.name
}
