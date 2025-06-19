# Development Environment Variables

variable "resource_group_name" {
  description = "AG/PSSG Azure Files PoC resource group"
  type        = string
  default     = "ag-pssg-azure-files-poc-dev-rg"
}

variable "location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "canadacentral"
}

variable "storage_account_name" {
  description = "AG/PSSG Azure Files PoC storage account"
  type        = string
  default     = "agpssgfilespocdevsa"
}

variable "file_share_name" {
  description = "AG/PSSG Azure Files PoC Azure file share"
  type        = string
  default     = "ag-pssg-poc-dev-share"
}

variable "file_share_quota_gb" {
  description = "Size of the file share in GB"
  type        = number
  default     = 100
}

variable "vnet_name" {
  description = "AG/PSSG Azure Files PoC virtual network"
  type        = string
  default     = "ag-pssg-files-poc-dev-vnet"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_name" {
  description = "AG/PSSG Azure Files PoC subnet"
  type        = string
  default     = "ag-pssg-files-poc-dev-subnet"
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for the subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "common_tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    project     = "ag-pssg-azure-files-poc"
    owner       = "ag-pssg-teams"
    ministry    = "ag-pssg"
    costcenter  = "ag-pssg-financecode"
  }
}
