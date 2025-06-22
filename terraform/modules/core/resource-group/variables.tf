# --- terraform/modules/core/resource-group/variables.tf ---

variable "name" {
  description = "The name of the Resource Group."
  type        = string
}

variable "location" {
  description = "The Azure region where the Resource Group will be created."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to the Resource Group."
  type        = map(string)
  default     = {}
}