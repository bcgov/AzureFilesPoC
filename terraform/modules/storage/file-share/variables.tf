# terraform/modules/storage/file-share/variables.tf

# --- FIX for azurerm v3.75.0 ---
# This variable now correctly expects the NAME of the storage account.
variable "storage_account_name" {
  type        = string
  description = "The name of the existing storage account where the share will be created."
}

variable "file_share_name" {
  type        = string
  description = "The name of the file share to create."
}

variable "quota_gb" {
  type        = number
  description = "The quota of the file share in GiB."
}

variable "enabled_protocol" {
  type        = string
  description = "The protocol to enable on the file share. e.g., 'SMB' or 'NFS'."
  default     = "SMB"
}

variable "access_tier" {
  type        = string
  description = "The access tier of the file share. Can be 'Hot', 'Cool', 'TransactionOptimized', or 'Premium'."
  default     = "Hot"
}

variable "metadata" {
  type        = map(string)
  description = "A map of metadata to assign to the share."
  default     = {}
}

variable "acls" {
  type = list(object({
    id          = string
    permissions = string
    start       = optional(string)
    expiry      = optional(string)
  }))
  description = "A list of Access Control Lists for the file share."
  default     = []
}

variable "service_principal_id" {
  description = "The object ID of the service principal or user to assign least-privilege access to the file share."
  type        = string
}

# Optional variables for completeness
variable "enabled_onboarded_windows_acl" {
  type        = bool
  description = "Enable NTFS ACL support for Azure Files."
  default     = false
}

variable "root_squash" {
  type        = string
  description = "Root squash setting for NFS shares."
  default     = null
}

variable "storage_account_id" {
  type        = string
  description = "The ARM resource ID of the storage account where the share will be created. Used for RBAC scope."
}