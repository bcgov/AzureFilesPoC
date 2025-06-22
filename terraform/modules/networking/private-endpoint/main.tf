# Creates a Private Endpoint to connect a resource to a subnet.

resource "azurerm_private_endpoint" "main" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.name}"
    is_manual_connection           = false
    private_connection_resource_id = var.private_connection_resource_id
    subresource_names              = var.subresource_names
  }

  # This lifecycle block is critical to prevent conflicts with Azure Policy
  # that might automatically manage DNS zone group associations.
  lifecycle {
    ignore_changes = [private_dns_zone_group]
  }
}