output "id" {
  description = "The ID of the created Subnet."
  value       = azurerm_subnet.main.id
}

output "name" {
  description = "The name of the created Subnet."
  value       = azurerm_subnet.main.name
}

output "nsg_id" {
  description = "The ID of the Network Security Group created for the subnet."
  value       = azurerm_network_security_group.main.id
}