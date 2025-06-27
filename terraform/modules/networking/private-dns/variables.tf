variable "dns_zone_name" {
  description = "The name of the Private DNS Zone."
  type        = string
}

variable "resource_group_name" {
  description = "The resource group for the Private DNS Zone."
  type        = string
}

variable "vnet_link_name" {
  description = "The name of the VNet link."
  type        = string
}

variable "virtual_network_id" {
  description = "The ID of the virtual network to link."
  type        = string
}

variable "registration_enabled" {
  description = "Whether auto-registration is enabled."
  type        = bool
  default     = false
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
