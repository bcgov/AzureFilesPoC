variable "vnet_gateway_name" {
  description = "The name of the Virtual Network Gateway."
  type        = string
}

variable "resource_group_name" {
  description = "The resource group for the Virtual Network Gateway."
  type        = string
}

variable "location" {
  description = "The Azure region."
  type        = string
}

variable "gateway_type" {
  description = "The type of the gateway (Vpn or ExpressRoute)."
  type        = string
}

variable "vpn_type" {
  description = "The VPN type (RouteBased or PolicyBased)."
  type        = string
}

variable "sku" {
  description = "The SKU of the gateway."
  type        = string
}

variable "ip_configurations" {
  description = "A list of IP configuration blocks."
  type        = any
}

variable "tags" {
  description = "A map of tags to apply."
  type        = map(string)
  default     = {}
}

variable "service_principal_id" {
  description = "The object ID of the service principal or user to assign least-privilege access."
  type        = string
}
