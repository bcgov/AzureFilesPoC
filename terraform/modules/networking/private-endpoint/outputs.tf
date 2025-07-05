output "private_endpoint_id" {
  description = "The ID of the created Private Endpoint."
  value       = azurerm_private_endpoint.main.id
}

output "private_endpoint_ip_addresses" {
  description = "The list of private IP addresses assigned to the Private Endpoint."
  value       = azurerm_private_endpoint.main.private_service_connection[0].private_ip_address
}

output "private_endpoint_name" {
  description = "The name of the Private Endpoint."
  value       = azurerm_private_endpoint.main.name
}
