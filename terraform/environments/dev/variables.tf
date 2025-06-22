# --- terraform/environments/dev/variables.tf ---
#
# This file defines the "contract" or inputs required to deploy the 'dev' environment.
# The variable names align with the project-wide convention.

variable "dev_location" {
  description = "The primary Azure region for the dev environment."
  type        = string
}

variable "dev_resource_group" {
  description = "The name of the new resource group for PoC services."
  type        = string
}

variable "dev_storage_account_name" {
  description = "The globally unique name for the PoC storage account."
  type        = string
}

variable "dev_vnet_name" {
  description = "The name of the existing VNet to connect to."
  type        = string
}

variable "dev_vnet_resource_group" {
  description = "The name of the resource group where the existing VNet is located."
  type        = string
}

variable "dev_subnet_name" {
  description = "The name of the new subnet for private endpoints."
  type        = string
}

variable "dev_subnet_address_prefixes" {
  description = "A list of CIDR address blocks for the new subnet."
  type        = list(string)
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}