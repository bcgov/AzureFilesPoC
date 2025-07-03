variable "private_endpoint_name" {
  description = "The name of the Private Endpoint."
  type        = string
}

variable "location" {
  description = "The Azure region for the Private Endpoint."
  type        = string
}

variable "resource_group" {
  description = "The resource group for the Private Endpoint."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "The subnet ID for the Private Endpoint."
  type        = string
}

variable "private_service_connection_name" {
  description = "The name of the private service connection."
  type        = string
}

variable "private_connection_resource_id" {
  description = "The resource ID to connect to."
  type        = string
}

variable "subresource_names" {
  description = "A list of subresource names for the connection."
  type        = list(string)
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "service_principal_id" {
  description = "The object ID of the service principal or user to assign least-privilege access to the private endpoint."
  type        = string
}