output "id" {
  description = "The ID of the created Virtual Network."
  value       = azurerm_virtual_network.main.id
}

output "name" {
  description = "The name of the created Virtual Network."
  value       = azurerm_virtual_network.main.name
}
