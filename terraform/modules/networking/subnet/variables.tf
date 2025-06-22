variable "subnet_name" {
  description = "The name of the subnet to create."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group where the NSG will be created."
  type        = string
}

variable "location" {
  description = "The Azure region for the NSG."
  type        = string
}

variable "vnet_name" {
  description = "The name of the existing Virtual Network."
  type        = string
}

variable "vnet_resource_group_name" {
  description = "The name of the Resource Group where the existing VNet is located."
  type        = string
}

variable "address_prefixes" {
  description = "A list of CIDR address blocks for the subnet."
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to apply to the resources."
  type        = map(string)
  default     = {}
}