# Dev Environment Updates: BC Gov Policy Compliance Implementation

## Overview
Updated the `dev/main.tf` environment to align with the working pattern from `cicd/main.tf` and comply with BC Gov Azure Policy requirements for NSG and subnet creation.

## Key Changes Made

### 1. Added AzAPI Provider Support
- Added `azapi` provider to the required providers in `terraform` block
- This provider is required for policy-compliant subnet creation

### 2. Updated Terraform Configuration
**File: `terraform/environments/dev/main.tf`**
- Added AzAPI provider configuration
- Added data source for existing VNet reference
- Replaced commented-out networking sections with working modules

### 3. Created Storage NSG Module
**File: `terraform/modules/storage/nsg/main.tf`**
- Created new module following the exact pattern from `bastion/nsg` module
- Implements the BC Gov policy-compliant approach: NSG + Subnet creation in single operation
- Uses AzAPI to create subnet with NSG association atomically

### 4. Updated Variables
**File: `terraform/environments/dev/variables.tf`**
- Added required variables for the new networking pattern:
  - `storage_network_security_group`
  - `storage_subnet_name` 
  - `storage_subnet_address_prefix`
  - `vnet_id`

## BC Gov Policy Compliance Pattern

### The Problem
BC Gov Azure Policy requires:
1. **Subnets must have NSG association at creation time**
2. **Standard Terraform `azurerm_subnet` cannot create subnet + NSG association in single step**
3. **This causes policy violations and deployment failures**

### The Solution
**Two-step atomic operation using AzAPI:**

1. **Create NSG first** (using standard `azurerm_network_security_group`)
2. **Create subnet with NSG association** (using `azapi_resource`) in single operation

```hcl
# Step 1: Create NSG
resource "azurerm_network_security_group" "storage" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  # ... security rules ...
}

# Step 2: Create subnet with NSG association atomically
resource "azapi_resource" "storage_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name      = var.subnet_name
  parent_id = var.vnet_id
  body = jsonencode({
    properties = {
      addressPrefix = var.address_prefix
      networkSecurityGroup = {
        id = azurerm_network_security_group.storage.id
      }
    }
  })
}
```

## Module Pattern Benefits

1. **Policy Compliance**: Ensures NSG association at subnet creation time
2. **Reusability**: Encapsulates the complex AzAPI pattern in a simple module
3. **Consistency**: Same pattern used in both `cicd` and `dev` environments
4. **Dependency Management**: Prevents "AnotherOperationInProgress" errors

## Implementation in Dev Environment

The dev environment now uses the working pattern:

```hcl
# 2.1.1 Storage Subnet NSG - Creates both NSG and subnet with association
module "storage_nsg" {
  source              = "../../modules/storage/nsg"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.azure_location
  nsg_name            = var.storage_network_security_group
  tags                = var.common_tags
  vnet_id             = data.azurerm_virtual_network.spoke_vnet.id
  address_prefix      = var.storage_subnet_address_prefix[0]
  subnet_name         = var.storage_subnet_name
}
```

## Next Steps

1. **Update terraform.tfvars**: Add values for the new variables
2. **Test locally**: Run `terraform plan` to validate the configuration
3. **Deploy via GitHub Actions**: Once local validation passes
4. **Add private endpoints**: Uncomment and configure private endpoint modules as needed

## Key Lessons Learned

1. **BC Gov Policy requires atomic subnet+NSG creation**
2. **AzAPI provider is essential for policy compliance**
3. **Module pattern ensures consistency across environments**
4. **Working pattern from `cicd` can be applied to other environments**
5. **Dependency management prevents Azure API conflicts**

## References

- [BC Gov Azure Policy Terraform Notes](../Resources/BcGovAzurePolicyTerraformNotes.md)
- [BC Gov Azure IaC Best Practices](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/)
- Working implementation: `terraform/environments/cicd/main.tf`
- Module implementation: `terraform/modules/bastion/nsg/main.tf`
