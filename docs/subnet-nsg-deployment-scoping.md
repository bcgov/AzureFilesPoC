# Subnet and NSG Deployment Scoping Guide

## IMPORTANT: Subnet and NSG Deployment Scoping

* Always deploy subnet Bicep modules at the VNet's resource group scope (e.g., RG_NETWORKING), not the PoC RG.
* The vnetResourceGroup parameter and --resource-group argument must match the VNet's actual resource group.
* NSGs are created in the PoC RG (RG_AZURE_FILES), but subnets must be created in the VNet's RG (RG_NETWORKING).
* All subnet-related az commands (existence checks, creation, confirmation) must use RG_NETWORKING. All NSG-related commands must use RG_AZURE_FILES.

## Resource Group Scope Reference

### Landing Zone Resources (Provided)
These resources exist in the landing zone and are **not created** by PoC automation:

- **RG_NETWORKING**: Contains the VNet and existing subnets
- **RG_NETWORK_WATCHER**: Network monitoring resources
- **RG_LZ_ASC_EXPORT**: Azure Security Center export resources

### PoC Resources (Created by Automation)
These resources are **created** in the PoC resource group (`RG_AZURE_FILES`):

- **NSGs**: Network Security Groups
- **VMs**: Virtual Machines
- **Bastion**: Bastion hosts
- **Storage Accounts**: Storage resources
- **Key Vaults**: Secrets management
- **AI Foundry**: ML workspaces and projects

## Deployment Command Examples

### Correct: Subnet Deployment
```powershell
# Deploy to VNet's resource group (RG_NETWORKING)
az deployment group create \
  --resource-group $RG_NETWORKING \
  --template-file subnet-create.bicep \
  --parameters vnetResourceGroup=$RG_NETWORKING
```

### Correct: NSG Deployment
```powershell
# Deploy to PoC resource group (RG_AZURE_FILES)
az deployment group create \
  --resource-group $RG_AZURE_FILES \
  --template-file nsg-vm.bicep
```

### Incorrect: Common Mistakes
```powershell
# WRONG: Deploying subnet to PoC RG
az deployment group create \
  --resource-group $RG_AZURE_FILES \  # ❌ Wrong RG
  --template-file subnet-create.bicep

# WRONG: Using wrong vnetResourceGroup parameter
az deployment group create \
  --resource-group $RG_NETWORKING \
  --template-file subnet-create.bicep \
  --parameters vnetResourceGroup=$RG_AZURE_FILES  # ❌ Wrong parameter
```

## Troubleshooting Scoping Issues

### Error: "Virtual network not found"
```
The Resource 'Microsoft.Network/virtualNetworks/my-vnet' under resource group 'rg-azure-files-poc' was not found.
```

**Solution**: You're deploying subnet to the wrong resource group. Use `RG_NETWORKING` for subnet deployments.

### Error: "Subnet already exists"
```
The resource 'Microsoft.Network/virtualNetworks/my-vnet/subnets/my-subnet' already exists.
```

**Solution**: Check if subnet exists in `RG_NETWORKING` before attempting to create it.

### Error: Authorization Failed
```
AuthorizationFailed: The client does not have authorization to perform action 'Microsoft.Network/virtualNetworks/subnets/write'
```

**Solution**: Ensure you have contributor access to `RG_NETWORKING` for subnet operations.

## Verification Commands

### Check VNet Location
```powershell
az network vnet show --name $VNET_SPOKE --resource-group $RG_NETWORKING --query location
```

### List Existing Subnets
```powershell
az network vnet subnet list --vnet-name $VNET_SPOKE --resource-group $RG_NETWORKING --output table
```

### Check NSG Location
```powershell
az network nsg show --name $NSG_VM --resource-group $RG_AZURE_FILES --query location
```

## Best Practices

1. **Always verify resource group scope** before running deployment commands
2. **Use environment variables** consistently (`$RG_NETWORKING`, `$RG_AZURE_FILES`)
3. **Test with `az deployment group validate`** before actual deployment
4. **Document any custom resource group assignments** in your deployment notes
5. **Use the task tracker** to record which resources go in which resource groups

## Related Documentation

- [Task Tracker](../task-tracker.md) - Current deployment status and resource locations
- [Bicep Scripts](../scripts/bicep/) - Individual deployment scripts with proper scoping
- [Environment Variables](../azure.env) - Resource group definitions