output "id" {
  description = "The ID of the created Private Endpoint."
  value       = azurerm_private_endpoint.main.id
}

output "name" {
  description = "The name of the created Private Endpoint."
  value       = azurerm_private_endpoint.main.name
}