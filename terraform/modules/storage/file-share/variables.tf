# -----------------------------------------------------------------------------
# General & Environment Variables
# -----------------------------------------------------------------------------

variable "azure_location" {
  type        = string
  description = "The Azure region where resources will be created. e.g., 'canadacentral'."
}

variable "dev_resource_group" {
  type        = string
  description = "The name of the Resource Group where the Storage Account will be created."
}

variable "common_tags" {
  type        = map(string)
  description = "A map of common tags to apply to all created resources."
  default     = {}
}

# -----------------------------------------------------------------------------
# Storage Account Specific Variables
# -----------------------------------------------------------------------------

variable "dev_storage_account_name" {
  type        = string
  description = "The unique name for the Storage Account."
}