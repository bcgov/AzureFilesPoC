/*
 * =================================================================================================
 *   Azure Files PoC - CI/CD and Terraform Validation Script
 * =================================================================================================
 *
 * PURPOSE:
 * The primary purpose of this Terraform configuration is to serve as a comprehensive validation test
 * for the integration between GitHub Actions and Microsoft Azure. It confirms that the CI/CD
 * pipeline is correctly configured to deploy Infrastructure as Code (IaC) securely and
 * incrementally.
 *
 * -------------------------------------------------------------------------------------------------
 *
 * HIGH-LEVEL VALIDATION PROCESS:
 * This validation was performed in two distinct phases to ensure a stable, step-by-step
 * verification of the pipeline:
 *
 *   1. STEP 1: NETWORK FOUNDATION DEPLOYMENT
 *      - Action: Created the Resource Group, a Network Security Group (NSG), and a new Subnet
 *        within an existing Virtual Network.
 *      - Purpose: To confirm base connectivity, successful OIDC authentication, and the ability
 *        to modify existing Azure resources (the VNet) from the pipeline.
 *
 *   2. STEP 2: PAAS SERVICE DEPLOYMENT
 *      - Action: Created the policy-compliant Storage Account (no public access) and a Private
 *        Endpoint connecting it to the new subnet.
 *      - Purpose: To validate policy compliance, dependency management (the PE depends on the
 *        subnet and storage account), and the successful creation of services on the foundation
 *        built in Step 1.
 *
 * -------------------------------------------------------------------------------------------------
 *
 * AZURE RESOURCES CREATED BY THIS SCRIPT:
 * The following resources will be created in your Azure subscription when this script is applied.
 *
 * | Azure Resource Type          | Terraform Resource Name                 | Azure Resource Name (Pattern)                     |
 * |------------------------------|-----------------------------------------|---------------------------------------------------|
 * | Resource Group               | azurerm_resource_group.validation       | rg-ag-pssg-azure-poc-dev                          |
 * | Network Security Group       | azurerm_network_security_group.validation | nsg-ag-pssg-azure-poc-dev-01                      |
 * | Subnet                       | azapi_resource.storage_pe_subnet        | snet-ag-pssg-azure-poc-dev-storage-pe             |
 * | Storage Account              | azurerm_storage_account.validation      | stagpssgazurepocdev01                             |
 * | Private Endpoint             | azurerm_private_endpoint.storage_pe     | pe-stagpssgazurepocdev01                          |
 *
 * -------------------------------------------------------------------------------------------------
 *
 * GITHUB DEPENDENCIES:
 * This pipeline requires the following secrets and variables to be configured in your GitHub
 * repository settings under "Settings > Secrets and variables > Actions".
 *
 * GITHUB SECRETS
 * | Secret Name                 | Description                                                                     |
 * |-----------------------------|---------------------------------------------------------------------------------|
 * | AZURE_CLIENT_ID             | The Client ID (or Application ID) of the Azure Service Principal for OIDC auth. |
 * | AZURE_SUBSCRIPTION_ID       | The ID of the Azure subscription where resources will be deployed.              |
 * | AZURE_SUBSCRIPTION_NAME     | The display name of the Azure subscription (for reference).                     |
 * | AZURE_TENANT_ID             | The Tenant ID of the Azure Active Directory instance for OIDC authentication.   |
 * | DEV_RESOURCE_GROUP_NAME     | The name of the resource group this validation will create.                     |
 * | DEV_SUBSCRIPTION_ID         | The ID of the development subscription (can be the same as AZURE_...).          |
 * | DEV_SUBSCRIPTION_NAME       | The name of the development subscription (can be the same as AZURE_...).        |
 * | DEV_VNET_ID                 | The full Azure Resource ID of the existing Virtual Network to connect to.       |
 * | DEV_VNET_NAME               | The name of the existing Virtual Network where the new subnet will be created.  |
 * | DEV_VNET_RESOURCE_GROUP     | The name of the Resource Group where the existing Virtual Network is located.   |
 *
 * GITHUB VARIABLES
 * | Variable Name                 | Description                                                                     |
 * |-------------------------------|---------------------------------------------------------------------------------|
 * | AZURE_LOCATION                | The Azure region where all new resources will be deployed (e.g., 'canadacentral').|
 * | DEV_DNS_SERVERS               | A list of DNS server IP addresses for the VNet (e.g., `["10.0.0.4"]`).           |
 * | DEV_FILE_SHARE_NAME           | The desired name for the Azure File Share inside the storage account.           |
 * | DEV_FILE_SHARE_QUOTA_GB       | The size of the file share in Gigabytes (e.g., `10`). Must be a number.         |
 * | DEV_STORAGE_ACCOUNT_NAME      | The globally unique name for the new Azure Storage Account.                     |
 * | DEV_SUBNET_ADDRESS_PREFIXES   | The CIDR block for the new subnet as a list (e.g., `["10.0.1.0/24"]`).           |
 * | DEV_SUBNET_NAME               | The desired name for the new subnet to be created.                              |
 * | DEV_VNET_ADDRESS_SPACE        | The address space of the existing VNet as a list (e.g., `["10.0.0.0/16"]`).     |
 *
 * -------------------------------------------------------------------------------------------------
 *
 * KEY CONCEPTS VALIDATED:
 *   ✅ CI/CD Pipeline Execution: The GitHub Actions workflow triggers and runs successfully.
 *   ✅ Secure OIDC Authentication: Connects to Azure without long-lived secrets.
 *   ✅ GitHub Secrets & Variables: Securely passes values to Terraform using TF_VAR_ environment vars.
 *   ✅ Incremental/Phased Deployment: The two-step process proves safe, additive changes.
 *   ✅ Azure Policy Compliance: The private storage account is created without being blocked.
 *   ✅ Terraform State Management: The pipeline correctly identifies existing resources and only
 *      adds what's new, preserving the existing infrastructure.
 *
 */

/*
 * Azure Files PoC - Terraform Validation Configuration
 * STEP 2: Enable the Storage Account and Private Endpoint.
 */

# Configure the Azure and AzAPI providers
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

# --- All your variable definitions are correct ---
variable "dev_location" { type = string }
variable "environment" { type = string }
variable "dev_resource_group" { type = string }
variable "common_tags" { type = map(string) }
variable "dev_vnet_name" { type = string }
variable "dev_subnet_name" { type = string }
variable "dev_subnet_address_prefixes" { type = list(string) }
variable "dev_vnet_resource_group" { type = string }
variable "dev_subscription_name" { type = string }
variable "dev_subscription_id" { type = string }
variable "dev_storage_account_name" { type = string }
variable "dev_file_share_name" { type = string }
variable "dev_file_share_quota_gb" { type = number }
variable "dev_vnet_id" { type = string }
variable "dev_vnet_address_space" { type = list(string) }
variable "dev_dns_servers" { type = list(string) }

# Local variables
locals {
  project_prefix    = "ag-pssg-azure-poc"
  env               = var.environment
  rg_name           = "rg-${local.project_prefix}-${local.env}"
  st_name           = var.dev_storage_account_name
  nsg_name          = "nsg-${local.project_prefix}-${local.env}-01"
  dev_subnet_name   = var.dev_subnet_name
  dev_subnet_prefix = var.dev_subnet_address_prefixes
}

# Resource group for validation
resource "azurerm_resource_group" "validation" {
  name     = local.rg_name
  location = var.dev_location
  tags     = var.common_tags
}

# Network Security Group (NSG) for validation subnet
resource "azurerm_network_security_group" "validation" {
  name                = local.nsg_name
  location            = var.dev_location
  resource_group_name = azurerm_resource_group.validation.name
  tags                = var.common_tags
}

# Reference the existing VNet
data "azurerm_virtual_network" "existing" {
  name                = var.dev_vnet_name
  resource_group_name = var.dev_vnet_resource_group
}

# Create subnet using AzAPI with NSG association
resource "azapi_resource" "storage_pe_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name      = local.dev_subnet_name
  parent_id = data.azurerm_virtual_network.existing.id
  body = jsonencode({
    properties = {
      addressPrefix                     = local.dev_subnet_prefix[0]
      networkSecurityGroup              = { id = azurerm_network_security_group.validation.id }
      privateEndpointNetworkPolicies    = "Disabled"
      privateLinkServiceNetworkPolicies = "Disabled"
    }
  })
  response_export_values = ["id"]
}

# --- UNCOMMENTED FOR STEP 2 ---
# The Storage Account will now be created.
resource "azurerm_storage_account" "validation" {
  name                     = local.st_name
  resource_group_name      = azurerm_resource_group.validation.name
  location                 = var.dev_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  large_file_share_enabled = true
  access_tier              = "Hot"
  tags                     = var.common_tags
  public_network_access_enabled = false
}

# --- UNCOMMENTED FOR STEP 2 ---
# The Private Endpoint will now be created.
resource "azurerm_private_endpoint" "storage_pe" {
  name                = "pe-${local.st_name}"
  location            = var.dev_location
  resource_group_name = azurerm_resource_group.validation.name
  subnet_id           = jsondecode(azapi_resource.storage_pe_subnet.output).id

  private_service_connection {
    name                           = "psc-${local.st_name}"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.validation.id
    subresource_names              = ["blob", "file"]
  }

  lifecycle {
    ignore_changes = [ private_dns_zone_group ]
  }
}

# --- Outputs for all resources ---
output "resource_group_name" {
  description = "The name of the validation resource group"
  value       = azurerm_resource_group.validation.name
}

output "subnet_id" {
  description = "The ID of the created subnet"
  value       = jsondecode(azapi_resource.storage_pe_subnet.output).id
}

# --- UNCOMMENTED FOR STEP 2 ---
# These outputs are now active.
output "storage_account_name" {
  description = "The name of the created storage account"
  value       = azurerm_storage_account.validation.name
}

output "storage_account_id" {
  description = "The ID of the created storage account"
  value       = azurerm_storage_account.validation.id
}

output "storage_account_resource_group" {
  description = "The resource group of the storage account"
  value       = azurerm_storage_account.validation.resource_group_name
}

output "storage_account_location" {
  description = "The location of the storage account"
  value       = azurerm_storage_account.validation.location
}