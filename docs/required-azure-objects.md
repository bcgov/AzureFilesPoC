# Required Azure Objects for Landing Zone Deployment

This document lists all Azure resources required for a secure, landing zone–compliant deployment with Azure Foundry, Bastion, and a VM, including private endpoints and supporting resources.

## Resource Group
- rg-ag-pssg-azure-files-azure-foundry

## Networking
- Existing VNet: d5007d-dev-vwan-spoke
- Subnets:
  - snet-ag-pssg-azure-files-vm (for VM)
  - AzureBastionSubnet (for Bastion)
  - snet-ag-pssg-azure-files-pe (for Private Endpoints, optional)

## Network Security Groups (NSGs)
- nsg-ag-pssg-azure-files-azure-foundry (for VM subnet)
- nsg-ag-pssg-azure-files-azure-foundry-bastion (for Bastion subnet)
- nsg-ag-pssg-azure-files-azure-foundry-pe (for Private Endpoint subnet, optional)

## Bastion
- bastion-ag-pssg-azure-files (Azure Bastion resource)
- bastion-ag-pssg-azure-files-nic (NIC for Bastion)
- bastion-ag-pssg-azure-files-pip (Public IP for Bastion)

## Virtual Machine
- vm-ag-pssg-azure-files-01 (VM)
- vm-ag-pssg-azure-files-01-nic (NIC for VM)
- vm-ag-pssg-azure-files-01-osdisk (Managed OS disk)
- vm-ag-pssg-azure-files-01-datadisk (Managed data disk, optional)

## Azure Foundry/Workspace
- foundry-ag-pssg-azure-files (Foundry resource)
- foundry-ag-pssg-azure-files-project (Foundry project)

## Private Endpoints
- pe-ag-pssg-azure-files-storage (Private Endpoint for Storage)
- pe-ag-pssg-azure-files-keyvault (Private Endpoint for Key Vault)

## Other
- Storage Account: stagpssgazurepocdev01 (for boot diagnostics or data)
- Key Vault: kv-ag-pssg-azure-files
- Log Analytics Workspace: law-ag-pssg-azure-files
- User-Assigned Managed Identity: uami-ag-pssg-azure-files (if required)
