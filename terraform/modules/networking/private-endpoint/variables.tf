variable "dev_private_endpoint_name" {
  description = "The name of the Private Endpoint."
  type        = string
}

variable "dev_location" {
  description = "The Azure region for the Private Endpoint."
  type        = string
}

variable "dev_resource_group" {
  description = "The resource group for the Private Endpoint."
  type        = string
}

variable "dev_private_endpoint_subnet_id" {
  description = "The subnet ID for the Private Endpoint."
  type        = string
}

variable "dev_private_service_connection_name" {
  description = "The name of the private service connection."
  type        = string
}

variable "dev_private_connection_resource_id" {
  description = "The resource ID to connect to."
  type        = string
}

variable "dev_subresource_names" {
  description = "A list of subresource names for the connection."
  type        = list(string)
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}