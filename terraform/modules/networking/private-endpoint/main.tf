# Creates a Private Endpoint for a resource.

resource "azurerm_private_endpoint" "main" {
  name                = var.private_endpoint_name
  location            = var.azure_location
  resource_group_name = var.resource_group
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.common_tags

  private_service_connection {
    name                           = var.private_service_connection_name
    is_manual_connection           = false
    private_connection_resource_id = var.private_connection_resource_id
    subresource_names              = var.subresource_names
  }

  lifecycle {
    ignore_changes = [private_dns_zone_group]
  }
}

#==================================================================================
# Assign least-privilege role to the private endpoint resource
#==================================================================================
resource "azurerm_role_assignment" "private_endpoint_reader" {
  scope                = azurerm_private_endpoint.main.id
  role_definition_name = "Reader" # Adjust if a more restrictive or custom role is appropriate
  principal_id         = var.service_principal_id
}