variable "name" {
  description = "The name of the Private Endpoint."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group where the Private Endpoint will be created."
  type        = string
}

variable "location" {
  description = "The Azure region for the Private Endpoint."
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet to which the Private Endpoint should be connected."
  type        = string
}

variable "private_connection_resource_id" {
  description = "The resource ID of the service to connect to (e.g., a storage account)."
  type        = string
}

variable "subresource_names" {
  description = "The sub-resource(s) to connect to (e.g., ['blob', 'file'])."
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to apply to the resource."
  type        = map(string)
  default     = {}
}