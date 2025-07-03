# Bastion NSG Module
#
# Assumptions / Constraints:
# - This module creates a Network Security Group (NSG) with all required Bastion rules.
# - In strict BC Gov/Azure policy environments, service principals may NOT have permission to create subnets with NSG association in a single step (required by policy).
# - The Bastion subnet must be created with an NSG assigned at creation time, but this is often blocked for service principals by policy.
# - As a workaround, run the onboarding script `step9_create_subnet.sh` to create the subnet manually after this NSG is created.
# - The subnet can only be created after this NSG exists.
# - If your service principal has sufficient permissions and policy exemptions, you can uncomment and use the Terraform subnet resource below.
#
# Example usage:
#   module "bastion_nsg" {
#     source              = "../bastion/nsg"
#     resource_group_name = var.resource_group_name
#     location            = var.location
#     nsg_name            = var.nsg_name
#     tags                = var.tags
#   }
#
# To create the subnet manually (workaround):
#   bash step9_create_subnet.sh --vnetname <vnet> --vnetrg <vnet-rg> --subnetname AzureBastionSubnet --addressprefix <prefix> --nsg <nsg-name>
#
# To use Terraform for subnet creation (if allowed), uncomment below:
#
# resource "azapi_resource" "bastion_subnet" {
#   type      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
#   name      = "AzureBastionSubnet"
#   parent_id = data.azurerm_virtual_network.vnet.id
#   body = jsonencode({
#     properties = {
#       addressPrefix = var.address_prefix
#       networkSecurityGroup = {
#         id = azurerm_network_security_group.bastion.id
#       }
#     }
#   })
# }
#
# output "bastion_subnet_id" {
#   value = azapi_resource.bastion_subnet.id
# }

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "nsg_name" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_network_security_group" "bastion" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags


# --- Inbound Security Rules ---

  security_rule {
    name                       = "AllowTagHTTPSInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAnyHTTPSInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowBastionHostCommunication"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*" # "Any" in portal
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowGatewayManagerInbound"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  # --- Outbound Security Rules ---

  security_rule {
    name                       = "AllowSshRdpOutbound"
    priority                   = 140
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*" # "Any" in portal
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowAzureCloudOutbound"
    priority                   = 150
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*" # "Any" in portal
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }

  security_rule {
    name                       = "AllowBastionCommunication"
    priority                   = 160
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*" # "Any" in portal
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowHttpOutbound"
    priority                   = 170
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*" # "Any" in portal
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}
  
output "bastion_nsg_id" {
  value = azurerm_network_security_group.bastion.id
}

variable "vnet_id" {
  description = "The ID of the Virtual Network where the Bastion subnet will be created."
  type        = string
}

variable "address_prefix" {
  description = "The address prefix to use for the AzureBastionSubnet."
  type        = string
}

variable "subnet_name" {
  description = "The name to use for the Bastion subnet."
  type        = string
}

resource "azapi_resource" "bastion_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name      = var.subnet_name
  parent_id = var.vnet_id
  body = jsonencode({
    properties = {
      addressPrefix = var.address_prefix
      networkSecurityGroup = {
        id = azurerm_network_security_group.bastion.id
      }
    }
  })
}

output "bastion_subnet_id" {
  value = azapi_resource.bastion_subnet.id
}