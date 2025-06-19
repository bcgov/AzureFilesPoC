# Variables for Azure Files PoC Terraform Configuration
# 
# IMPORTANT CONTEXT:
# This file only assigns values to variables defined in variables.tf
# No Azure resources are created just by having this file
# Resources are only created when you explicitly run 'terraform apply' (which we haven't done)
#
# ❗ CRITICAL RULE: DO NOT CREATE ANY RESOURCES IN AZURE WITHOUT EXPLICIT CONSENT AND REVIEW ❗

resource_group_name = "ag-pssg-azure-files-poc-rg"
location           = "canadacentral"  # Default BC Gov region
storage_account_name = "agpssgazfilespocsa" # Must be globally unique
file_share_name    = "ag-pssg-pocshare"
file_share_quota_gb = 100

# Network settings
vnet_name = "ag-pssg-azure-files-poc-vnet"
vnet_address_space = ["10.0.0.0/16"]
subnet_name = "ag-pssg-azure-files-poc-client-subnet"
subnet_address_prefixes = ["10.0.1.0/24"]

common_tags = {
  environment = "poc"
  project     = "ag-pssg-azure-files-poc"
  owner       = "ag-pssg-teams"
  ministry    = "ag-pssg"
  costcenter  = "ag-pssg-financecode"
}
