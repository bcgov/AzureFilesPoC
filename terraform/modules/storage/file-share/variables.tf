variable "file_share_name" {
  description = "The name of the Azure File Share."
  type        = string
}

variable "storage_account_name" {
  description = "The name of the Storage Account to contain the file share."
  type        = string
}

variable "quota_gb" {
  description = "The maximum size of the file share in GB."
  type        = number
  default     = 100
}

variable "enabled_protocol" {
  description = "The protocol to use for the file share (e.g., 'SMB')."
  type        = string
  default     = "SMB"
}

variable "metadata" {
  description = "A map of metadata to assign to the file share."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "A map of tags to assign to the file share."
  type        = map(string)
  default     = {}
}
