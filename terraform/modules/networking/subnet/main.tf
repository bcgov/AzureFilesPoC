# Creates a dedicated, secure subnet within an existing VNet.

locals {
  # Automatically create an NSG name based on the subnet name for consistency.
  nsg_name = "nsg-${var.subnet_name}"
}

# Look up the existing VNet where the subnet will be created.
data "azurerm_virtual_network" "parent" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

# Create a dedicated Network Security Group for this subnet.
resource "azurerm_network_security_group" "main" {
  name                = local.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Create the subnet itself and associate the NSG.
# Using azapi_resource as it was in your validation script.
resource "azapi_resource" "subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name      = var.subnet_name
  parent_id = data.azurerm_virtual_network.parent.id
  body = jsonencode({
    properties = {
      addressPrefixes = var.address_prefixes
      networkSecurityGroup = {
        id = azurerm_network_security_group.main.id
      }
      # These must be disabled for Private Endpoints to work correctly.
      privateEndpointNetworkPolicies    = "Disabled"
      privateLinkServiceNetworkPolicies = "Disabled"
    }
  })
  response_export_values = ["id", "name"]
}

# Creates a Subnet within a Virtual Network.

resource "azurerm_subnet" "main" {
  name                 = var.dev_subnet_name
  resource_group_name  = var.dev_vnet_resource_group
  virtual_network_name = var.dev_vnet_name
  address_prefixes     = var.dev_subnet_address_prefixes
}