# BC Government Virtual Network Module

**Note:** In the BC Gov Azure Landing Zone, Virtual Networks (VNets) are pre-provisioned for your project in alignment with the hub and spoke design.  Our subscriptions are provisioned with a spoke VNET. You should **not create new VNets**. Instead, reference the existing VNet assigned to your project using a data source.

## How to Reference Your Existing VNet
- Use the `/OneTimeActivities/` scripts to discover your assigned VNet and network details. These scripts populate `.env/azure_full_inventory.json`.
- The discovered values (VNet name, resource group, address space, etc.) are mapped into your `terraform.tfvars` and `secrets.tfvars` files.
- Reference the existing VNet in your Terraform code using a `data` block, for example:

```hcl
data "azurerm_virtual_network" "existing" {
  name                = var.vnet_name
  resource_group_name = var.resource_group
}
```

## Example Usage (Reference Only)
```hcl
# Reference the existing VNet (do not create)
data "azurerm_virtual_network" "existing" {
  name                = var.vnet_name
  resource_group_name = var.resource_group
}

# Create a subnet in the existing VNet
resource "azurerm_subnet" "example" {
  name                 = var.subnet_name
  resource_group_name  = var.resource_group
  virtual_network_name = data.azurerm_virtual_network.existing.name
  address_prefixes     = var.subnet_address_prefixes
}
```

## Requirements
- AzureRM provider
- BC Gov Landing Zone access
- Proper RBAC permissions
- Populate network variables using `/OneTimeActivities/` scripts and update your `terraform.tfvars` and `secrets.tfvars` files accordingly.

## Variables
See `variables.tf` for details.
