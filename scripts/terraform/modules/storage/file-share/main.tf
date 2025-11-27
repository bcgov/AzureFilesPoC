# terraform/modules/storage/file-share/main.tf

# This block is a best practice for modules to declare their provider requirements.
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      # This module is now compatible with provider version 3.75.0
      version = ">= 3.0"
    }
  }
}

# --------------------------------------------------------------------------------
# NOTE: Role, RBAC, and ACL Requirements for File Share
#
# - The service principal or user creating/managing the file share must have:
#   * Azure RBAC: "Storage File Data SMB Share Contributor" (or higher) assigned at the STORAGE ACCOUNT LEVEL.
# - RBAC controls management plane (create/delete/configure) and grants mount/access rights.
# - ACLs (NTFS/Windows permissions) control data plane (read/write/list within the share).
# --------------------------------------------------------------------------------
resource "azurerm_storage_share" "main" {
  # --- FIX for azurerm v3.75.0 ---
  # This older provider version requires 'storage_account_name' instead of 'storage_account_id'.
  # This argument specifies the name of the Storage Account in which the File Share should exist.
  storage_account_name = var.storage_account_name

  name   = var.file_share_name
  quota  = var.quota_gb

  # Corresponds to properties.enabledProtocols in an Azure export
  enabled_protocol = var.enabled_protocol

  # Corresponds to properties.accessTier in an Azure export
  # Common values are "Hot", "Cool", "TransactionOptimized", "Premium"
  access_tier = var.access_tier

  # Corresponds to the metadata property
  metadata = var.metadata

  # Defines file and folder-level permissions via Shared Access Policies.
  # Note: For granular identity-based access, you must configure NTFS ACLs
  # on the mounted share after creation.
  dynamic "acl" {
    for_each = var.acls
    content {
      id = acl.value.id
      access_policy {
        permissions = acl.value.permissions
        start       = acl.value.start
        expiry      = acl.value.expiry
      }
    }
  }
}

#==================================================================================
# Role assignment for file share contributor is managed at the storage account level in the environment configuration.
# Removed redundant azurerm_role_assignment resource to prevent duplicate assignment errors.
#==================================================================================