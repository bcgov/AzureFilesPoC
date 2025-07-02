# Copy this file to terraform.tfvars and fill in your real values
# Do NOT include secrets or sensitive values here

# Variables for Azure Files PoC Terraform Configuration
# 
# IMPORTANT CONTEXT:
# This file only assigns values to variables defined in variables.tf
# No Azure resources are created just by having this file
# Resources are only created when you explicitly run 'terraform apply' (which we haven't done)
#
# ❗ CRITICAL RULE: make sure that you don't put real values in this file
#                  use this template and copy as terraform.tfvars that is part of .gitignore
#                  populate with values contained in .env/azure_full_inventory.json
#                  that is populated by running OneTimeActivities/GetAzureExistingResources/unix/azure_full_inventory.sh

# Names in this file now directly match variables.tf
azure_location  = "canadacentral"

# PREPROVISIONED by LANDING ZONE BC Government
dev_service_principal_id = "e72f42f8-d9a1-4181-a0b9-5c8644a28aee"
dev_vnet_name             = "d5007d-dev-vwan-spoke"
dev_vnet_resource_group   = "d5007d-dev-networking"
dev_vnet_address_space     = ["10.46.73.0/24"]
dev_vnet_dns_servers       = ["10.46.73.0/24"]
dev_vnet_id               = "/subscriptions/d321bcbe-c5e8-4830-901c-dab5fab3a834/resourceGroups/d5007d-dev-networking/providers/Microsoft.Network/virtualNetworks/d5007d-dev-vwan-spoke"

# CREATED BY USER IDENTITY in AZURE policy won't allow by terraform
dev_resource_group       = "rg-ag-pssg-azure-poc-dev" 
dev_resource_id          = "/subscriptions/d321bcbe-c5e8-4830-901c-dab5fab3a834/resourceGroups/rg-ag-pssg-azure-poc-dev"

## CREATED BY TERRAFORM
dev_storage_account_name = "stagpssgazurepocdev01"

dev_file_share_name = "fspoc-ag-pssg-azure-files-poc-01"
dev_file_share_quota_gb = 10

dev_network_security_group = "nsg-ag-pssg-azure-poc-dev-01"

dev_subnet_name             = "snet-ag-pssg-azure-poc-dev-storage-pe"
dev_subnet_address_prefixes = ["10.46.73.224/27"]

dev_dns_servers = ["10.53.244.4"]

# Gateway Subnet for VPN Gateway
dev_gateway_subnet_name            = "GatewaySubnet"
DEV_GATEWAY_SUBNET_ADDRESS_PREFIX = ["10.46.73.224/27"]


# Virtual Network Gateway
dev_vng_name             = "vng-ag-pssg-azure-poc-dev"
dev_vng_public_ip_name   = "pip-vng-ag-pssg-azure-poc-dev"
dev_vng_sku              = "VpnGw1"
dev_vng_type             = "Vpn"
dev_vng_vpn_type         = "RouteBased"

dev_cicd_resource_group_name = "rg-ag-pssg-cicd-tools-dev"

# --- Bastion Host Variables ---
dev_bastion_name                   = "bastion-vm-ag-pssg-azure-poc-dev-01"
dev_bastion_subnet_name            = "AzureBastionSubnet"
dev_bastion_address_prefix         = ["10.46.73.64/26"]
dev_bastion_network_security_group = "nsg-bastion-vm-ag-pssg-azure-poc-dev-01"
dev_bastion_public_ip_name         = "pip-bastion-vm-ag-pssg-azure-poc-dev-01"

# --- Runner VM/Subnet Variables ---
dev_runner_network_security_group = "nsg-github-runners"
dev_runner_subnet_name           = "snet-agithub-runners"
dev_runner_vm_ip_address         = "10.46.73.17"
dev_runner_vm_name               = "vm-ag-pssg-azure-poc-dev-01"
dev_runner_vnet_address_space    = ["10.46.73.16/28"]
dev_runner_vm_admin_username     = "azureadmin"

# --- TF State Storage ---
dev_tfstate_container = "sc-ag-pssg-tfstate-dev"
dev_tfstate_rg        = "rg-ag-pssg-tfstate-dev"
dev_tfstate_sa        = "stagpssgtfstatedev01"

# --- Other Variables ---
dev_github_actions_spn_object_id = "e72f42f8-d9a1-4181-a0b9-5c8644a28aee"
dev_my_home_ip_address          = "108.172.9.11"

# --- Common Tags (override if needed) ---
dev_common_tags = {
  project        = "ag-pssg-azure-files-poc"
  owner          = "ag-pssg-teams"
  account_coding = "105150471019063011500000"
  billing_group  = "d5007d"
  ministry_name  = "AG"
}

admin_ssh_key_public       = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCzRd7BJMJ/3tWivLAMA4+Ct94V4Dofy5Jfp7H55VtRU3HyKw1vrnlXChi2Vc97GtTMFnqiRzRZXW1xbzGrfvOR6s5v9Z7Nce9T2mSoJ21REn70vgKy37MPAEVPFQXb8e9MBQ7imW3ireSeLG8PFd7OBpkJAo59B/vYloLFvSeNco6aAPysuJRCHj+xDUvbl+L/AJmxPQMlzWnSAL8829uEThaDpE81wtDYy6bo3ZugxFbPKbJHuPEJZsvPV0ehQpbM7TCChh05GfgRoc3Hd6nqVowMGVK8EDu6c/3LHj6jKhjDocNw+VLdVbv2ZvvTBXepPMp78V00DrdYeIUc8DA8MR/qpyFjpbXM2aZZAw9vrLamImaqpWUDjjODFIw3U9CBwrGj42oix6cw0Cpz6ew6qCmkNndhosnIml6Ev7kQrI/VWEg2oHX4T2llzeWb6FXLCNEIT1g4IRHbFGQbvGpebgP++MX2m3tN2EW/BboY+yvTimpnXJyHcV/Qc3J6pAYuuimFyJwcVS9WGcOaM7IMaez1sTMjmXRY2vHOeFOBljfkUOhTDnSoJVTMGokX0bP4NcmI8bATQax/T4iGb1ZAS+vi/OZ1g7OfxqpNtesTPcmeM7PjK5/QcAY7EZSYQocqw/JZ5VUsC2jQoTiTW29csT6btj2QKD5DQ9Sphm7rQQ== richard.fremmerlid@gov.bc.ca"


