variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "vnet_name" { type = string }
variable "vnet_resource_group" { type = string }
variable "bastion_name" { type = string }
variable "public_ip_name" { type = string }
variable "address_prefix" { type = string }
variable "network_security_group" {
  description = "The name of the NSG to associate with the Bastion subnet."
  type        = string
}

resource "azurerm_public_ip" "bastion" {
  name                = var.public_ip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.vnet_resource_group
  virtual_network_name = var.vnet_name
  address_prefixes     = [var.address_prefix]
}

resource "azurerm_bastion_host" "main" {
  name                = var.bastion_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_name            = null
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_network_security_group" "bastion" {
  name                = var.network_security_group
  location            = var.location
  resource_group_name = var.vnet_resource_group
  tags                = {
    environment = "bastion"
    managed_by  = "terraform"
  }
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}

output "bastion_host_id" {
  value = azurerm_bastion_host.main.id
}
output "bastion_host_name" {
  value = azurerm_bastion_host.main.name
}
output "bastion_public_ip" {
  value = azurerm_public_ip.bastion.ip_address
}
