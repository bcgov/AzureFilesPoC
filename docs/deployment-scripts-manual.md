# Azure Files PoC - Deployment Scripts Manual

## Overview

This manual provides a comprehensive guide to deploying and managing the Azure Files Proof of Concept infrastructure using Bicep templates and PowerShell scripts.

## Prerequisites

1. **Azure CLI** installed and configured
2. **PowerShell 5.1** or higher
3. **Azure subscription** access with appropriate permissions
4. **Git** for version control
5. Logged in to Azure CLI: `az login`

## Configuration

All deployment parameters are defined in `azure.env` at the root of the repository. Review and update values as needed before running scripts.

### Key Configuration Sections

- **Landing Zone Resources**: Pre-existing resources (VNet, Resource Groups)
- **PoC Resources**: Resources to be created by automation

## Deployment Sequence

### Phase 1: Network Security Groups (NSGs)

Create NSGs before subnets, as subnets require NSG associations.

```powershell
# Deploy all NSGs
.\scripts\bicep\deploy-nsg-vm.ps1
.\scripts\bicep\deploy-nsg-bastion.ps1
.\scripts\bicep\deploy-nsg-pe.ps1
```

**What it does:**
- Creates Network Security Groups in the PoC Resource Group
- Configures security rules based on BC Gov policies
- Each NSG is tailored for its subnet (VM, Bastion, Private Endpoints)

**Bicep templates used:**
- `bicep/nsg-snet-ag-pssg-azure-files-poc-dev-storage.bicep` (VM and PE NSGs)
- `bicep/nsg-bastion-ag-pssg-azure-files-poc-dev-01.bicep` (Bastion NSG)

---

### Phase 2: Subnets

Create subnets in the existing VNet with NSG associations.

```powershell
# Deploy all subnets
.\scripts\bicep\deploy-subnet-vm.ps1
.\scripts\bicep\deploy-subnet-bastion.ps1
.\scripts\bicep\deploy-subnet-pe.ps1

# Or deploy all at once
.\scripts\bicep\deploy-subnet-all.ps1
```

**What it does:**
- Creates subnets in the landing zone VNet (`d5007d-dev-vwan-spoke`)
- Associates each subnet with its corresponding NSG
- Configures private endpoint policies for PE subnet
- Uses CIDR-aligned address prefixes

**Bicep template used:**
- `bicep/subnet-create.bicep`

**IMPORTANT:** Subnets are deployed to the VNet's resource group (`RG_NETWORKING`), not the PoC resource group.

---

### Phase 3: Storage and Security

Deploy storage account, Key Vault, and managed identity.

```powershell
# Deploy storage account
.\scripts\bicep\deploy-storage.ps1

# Deploy Key Vault
.\scripts\bicep\deploy-keyvault.ps1

# Deploy User Assigned Managed Identity
.\scripts\bicep\deploy-uami.ps1
```

**What it does:**
- **Storage Account**: Creates storage with private access only, CMK encryption
- **Key Vault**: Creates Key Vault with private endpoint support
- **UAMI**: Creates managed identity for secure resource access

**Bicep templates used:**
- `bicep/storage-stagpssgazurepocdev01.bicep`
- `bicep/keyvault-ag-pssg-azure-files.bicep`
- `bicep/uami-ag-pssg-azure-files.bicep`

---

### Phase 4: Monitoring

Deploy Log Analytics Workspace for monitoring and diagnostics.

```powershell
# Deploy Log Analytics Workspace
.\scripts\bicep\deploy-law.ps1
```

**What it does:**
- Creates Log Analytics Workspace
- Configures retention policies
- Enables diagnostic logging

**Bicep template used:**
- `bicep/law-ag-pssg-azure-files.bicep`

---

### Phase 5: Compute Resources

Deploy VM and Bastion host for secure access.

```powershell
# Deploy Virtual Machine
.\scripts\bicep\deploy-vm-lz.ps1

# Deploy Bastion Host
.\scripts\bicep\deploy-bastion.ps1
```

**What it does:**
- **VM**: Creates Windows/Linux VM in VM subnet with managed disks
- **Bastion**: Deploys Azure Bastion with PIP and NIC for secure RDP/SSH access

**Bicep templates used:**
- `bicep/vm-lz-compliant.bicep`
- `bicep/bastion.bicep`, `bicep/bastion-nic.bicep`, `bicep/bastion-pip.bicep`

---

### Phase 6: Private Endpoints

Deploy private endpoints for secure PaaS service access.

```powershell
# Deploy private endpoints for Storage and Key Vault
.\scripts\bicep\deploy-private-endpoints.ps1
```

**What it does:**
- Creates private endpoints in PE subnet
- Configures DNS zones for private link
- Ensures no public access to PaaS services

**Bicep templates used:**
- `bicep/pe-storage.bicep`
- `bicep/pe-keyvault.bicep`

---

### Phase 7: Application Components

Deploy Azure Foundry resources.

```powershell
# Deploy Foundry
.\scripts\bicep\deploy-foundry.ps1

# Deploy Foundry Project
.\scripts\bicep\deploy-foundry-project.ps1
```

**What it does:**
- Creates Foundry workspace and projects
- Configures AI/ML resources

**Bicep templates used:**
- `bicep/foundry-ag-pssg-azure-files.bicep`
- `bicep/foundry-project.bicep`

---

## Verification

After each deployment phase, run the inventory script to verify resources:

```powershell
.\scripts\azure-inventory.ps1
```

**What it does:**
- Lists all Azure resources in the subscription
- Exports to JSON and TXT files in `scripts/azure-inventory/`
- Includes resource groups, VNets, subnets, NSGs, storage accounts, VMs, etc.

---

## Teardown / Cleanup

Remove resources in reverse order of creation to handle dependencies.

### Individual Resource Teardown

```powershell
# Foundry components
.\scripts\bicep\teardown-foundry-project.ps1
.\scripts\bicep\teardown-foundry.ps1

# Private endpoints
.\scripts\bicep\teardown-private-endpoints.ps1

# Compute resources
.\scripts\bicep\teardown-bastion.ps1
.\scripts\bicep\teardown-vm-lz.ps1

# Monitoring
.\scripts\bicep\teardown-law.ps1

# Security and storage
.\scripts\bicep\teardown-uami.ps1
.\scripts\bicep\teardown-keyvault.ps1
.\scripts\bicep\teardown-storage.ps1

# Subnets
.\scripts\bicep\teardown-subnet-pe.ps1
.\scripts\bicep\teardown-subnet-bastion.ps1
.\scripts\bicep\teardown-subnet-vm.ps1

# NSGs
.\scripts\bicep\teardown-nsgs.ps1
```

### Complete Teardown

```powershell
# Remove all PoC resources (master teardown script)
.\scripts\bicep\teardown-all.ps1
```

**What it does:**
- Removes all resources in dependency order
- Includes confirmation prompts
- Handles errors gracefully
- Allows selective teardown

---

## Script Features

### Idempotency

All deployment scripts check for existing resources before creating:
- Skip creation if resource already exists
- Update configuration if needed
- No errors on re-runs

### Error Handling

Scripts include robust error handling:
- Pre-flight checks for required variables
- Validation of Azure CLI commands
- Detailed error messages
- Exit codes for automation

### Debug Output

Scripts provide detailed debug information:
- Environment variable values
- Azure CLI commands executed
- Deployment status and progress
- Resource IDs and properties

---

## Common Issues and Solutions

### Issue: "Required variables missing"

**Solution:** Ensure `azure.env` is properly configured and all required variables are set.

### Issue: "NSG not found"

**Solution:** Deploy NSGs before subnets. Run NSG deployment scripts first.

### Issue: "Subnet creation fails"

**Solution:** 
- Verify CIDR ranges don't overlap
- Ensure VNet has available address space
- Check NSG exists in correct resource group

### Issue: "Script hangs or freezes"

**Solution:**
- Press Ctrl+C to cancel
- Check Azure portal for deployment status
- Review `az` CLI output for errors
- Verify Azure CLI is logged in

### Issue: "Parameter passing errors"

**Solution:**
- Use inline parameters instead of parameter files for PowerShell
- Ensure quotes are properly escaped
- Check Bicep template parameter names match script

---

## Best Practices

1. **Always review `azure.env`** before running scripts
2. **Run scripts in sequence** following the phases above
3. **Verify each phase** with inventory script before proceeding
4. **Use version control** for infrastructure changes
5. **Test teardown** in non-production before production use
6. **Document customizations** to scripts or templates
7. **Review BC Gov policies** before modifying security configurations

---

## Troubleshooting

### Enable Verbose Azure CLI Output

```powershell
$env:AZURE_CORE_COLLECT_TELEMETRY = "no"
$env:AZURE_CORE_OUTPUT = "jsonc"
```

### Check Deployment Logs

```powershell
# List recent deployments
az deployment group list --resource-group <resource-group-name> --output table

# Get deployment details
az deployment group show --resource-group <resource-group-name> --name <deployment-name>
```

### Validate Bicep Templates

```powershell
# Validate a Bicep template before deployment
az deployment group validate --resource-group <resource-group-name> --template-file <bicep-file>
```

---

## Additional Resources

- **IP Subnet Diagram**: `docs/ip-subnet-diagram.md`
- **Task Tracker**: `task-tracker.md`
- **Architecture Overview**: `Architecture/ArchitectureOverview.md`
- **BC Gov Policies**: `Resources/BCGov-*.md`

---

## Support

For issues or questions:
1. Check this manual first
2. Review task tracker for known issues
3. Consult BC Gov Azure documentation
4. Contact Azure landing zone team for platform issues
