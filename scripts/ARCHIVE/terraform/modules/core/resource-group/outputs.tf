output "resource_group_name" {
  description = "The name of the resource group."
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "The ID of the resource group."
  value       = azurerm_resource_group.main.id
}

output "resource_group_location" {
  description = "The Azure region of the resource group."
  value       = azurerm_resource_group.main.location
}

output "service_principal_id" {
  description = "The object ID of the service principal for role assignments."
  value       = var.service_principal_id
}
