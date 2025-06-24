# Creates a Private Endpoint for a resource.

resource "azurerm_private_endpoint" "main" {
  name                = var.dev_private_endpoint_name
  location            = var.dev_location
  resource_group_name = var.dev_resource_group
  subnet_id           = var.dev_private_endpoint_subnet_id
  tags                = var.common_tags

  private_service_connection {
    name                           = var.dev_private_service_connection_name
    is_manual_connection           = false
    private_connection_resource_id = var.dev_private_connection_resource_id
    subresource_names              = var.dev_subresource_names
  }

  lifecycle {
    ignore_changes = [private_dns_zone_group]
  }
}