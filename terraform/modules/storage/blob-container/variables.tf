# ../../modules/storage/blob-container/variables.tf

variable "container_name" {
  description = "The name of the storage container"
  type        = string
}

variable "storage_account_name" {
  description = "The name of the storage account"
  type        = string
}

variable "storage_account_id" {
  description = "The ID of the storage account"
  type        = string
}

variable "container_access_type" {
  description = "The access type of the container (private, blob, or container)"
  type        = string
  default     = "private"
  
  validation {
    condition     = contains(["private", "blob", "container"], var.container_access_type)
    error_message = "Container access type must be 'private', 'blob', or 'container'."
  }
}

variable "metadata" {
  description = "A map of metadata to assign to the storage container"
  type        = map(string)
  default     = {}
}