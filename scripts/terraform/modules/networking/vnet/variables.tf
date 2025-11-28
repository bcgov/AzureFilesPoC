variable "vnet_name" {
  description = "The name of the Virtual Network."
  type        = string
}

variable "location" {
  description = "The Azure region for the VNet."
  type        = string
}

variable "vnet_resource_group" {
  description = "The resource group for the VNet."
  type        = string
}

variable "vnet_address_space" {
  description = "The address space for the VNet."
  type        = list(string)
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}
