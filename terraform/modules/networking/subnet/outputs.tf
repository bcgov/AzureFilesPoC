output "id" {
  description = "The ID of the created subnet."
  value       = jsondecode(azapi_resource.subnet.output).id
}

output "name" {
  description = "The name of the created subnet."
  value       = jsondecode(azapi_resource.subnet.output).name
}

output "nsg_id" {
  description = "The ID of the Network Security Group created for the subnet."
  value       = azurerm_network_security_group.main.id
}