# IMPORTANT CONTEXT:
# This is a Terraform configuration file that defines variables - it doesn't create any resources in Azure.
# This is important to understand:
#
# - This file only declares what variables exist and their default values
# - No Azure resources are created just by having this file
# - Resources are only created when you explicitly run 'terraform apply' (which we haven't done)
#
# The variables defined here will be referenced in main.tf, but nothing happens until you explicitly
# run the terraform apply command, which requires your confirmation.

variable "resource_group_name" {
  description = "AG/PSSG Azure Files PoC resource group"
  type        = string
  default     = "ag-pssg-azure-files-poc-rg"
}

variable "location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "canadacentral" # Default to Canada Central for BC Gov
}

variable "storage_account_name" {
  description = "AG/PSSG Azure Files PoC storage account"
  type        = string
  # Must be globally unique, lowercase, and alphanumeric
  default     = "ag-pssg-azfilespocsa"
}

variable "file_share_name" {
  description = "AG/PSSG Azure Files PoC Azure file share"
  type        = string
  default     = "ag-pssg-pocshare"
}

variable "file_share_quota_gb" {
  description = "Size of the file share in GB"
  type        = number
  default     = 100
}

variable "vnet_name" {
  description = "AG/PSSG Azure Files PoC virtual network"
  type        = string
  default     = "ag-pssg-azure-files-poc-vnet"
}

variable "vnet_address_space" {
  description = "Address space for the AG/PSSG Azure Files PoC virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_name" {
  description = "AG/PSSG Azure Files PoC subnet"
  type        = string
  default     = "ag-pssg-azure-files-poc-client-subnet"
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for the subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "common_tags" {
  description = "Tags to apply to all AG/PSSG Azure Files PoC resources"
  type        = map(string)
  default = {
    environment = "poc"
    project     = "ag-pssg-azure-files-poc"
    owner       = "ag-pssg-teams"
    ministry    = "ag-pssg"
    costcenter  = "ag-pssg-financecode"
  }
}
