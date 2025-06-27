output "id" {
  description = "The ID of the Azure Firewall."
  value       = azurerm_firewall.main.id
}

output "name" {
  description = "The name of the Azure Firewall."
  value       = azurerm_firewall.main.name
}
