# Azure Landing Zone Deployment Task Tracker

This tracker lists all required objects for your landing zone deployment, the recommended creation sequence, and the associated Bicep scripts to run. Check off each step as you complete it.

| Step | Object Type                | Name/Description                                 | Bicep Script                                 | Status |
|------|----------------------------|--------------------------------------------------|-----------------------------------------------|--------|
| 1    | Resource Group             | rg-ag-pssg-azure-files-azure-foundry             | (manual or az cli)                            | [ ]    |
| 2    | NSG (VM subnet)            | nsg-ag-pssg-azure-files-azure-foundry            | bicep/nsg-ag-pssg-azure-files-azure-foundry.bicep | [ ]    |
| 3    | NSG (Bastion subnet)       | nsg-ag-pssg-azure-files-azure-foundry-bastion    | bicep/nsg-ag-pssg-azure-files-azure-foundry-bastion.bicep | [ ]    |
| 4    | NSG (PE subnet, optional)  | nsg-ag-pssg-azure-files-azure-foundry-pe         | bicep/nsg-ag-pssg-azure-files-azure-foundry-pe.bicep | [ ]    |
| 5    | Subnet (VM)                | snet-ag-pssg-azure-files-vm                      | (existing or bicep/subnet-vm.bicep)           | [ ]    |
| 6    | Subnet (Bastion)           | AzureBastionSubnet                               | (existing or bicep/subnet-bastion.bicep)      | [ ]    |
| 7    | Subnet (PE, optional)      | snet-ag-pssg-azure-files-pe                      | (existing or bicep/subnet-pe.bicep)           | [ ]    |
| 8    | Bastion Public IP          | bastion-ag-pssg-azure-files-pip                  | bicep/bastion-pip.bicep                       | [ ]    |
| 9    | Bastion NIC                | bastion-ag-pssg-azure-files-nic                  | bicep/bastion-nic.bicep                       | [ ]    |
| 10   | Azure Bastion              | bastion-ag-pssg-azure-files                      | bicep/bastion.bicep                           | [ ]    |
| 11   | VM NIC                     | vm-ag-pssg-azure-files-01-nic                    | bicep/vm-nic.bicep                            | [ ]    |
| 12   | VM                         | vm-ag-pssg-azure-files-01                        | bicep/vm-lz-compliant.bicep                   | [ ]    |
| 13   | OS Disk                    | vm-ag-pssg-azure-files-01-osdisk                 | (created by VM Bicep)                         | [ ]    |
| 14   | Data Disk (optional)       | vm-ag-pssg-azure-files-01-datadisk               | bicep/vm-datadisk.bicep                       | [ ]    |
| 15   | Storage Account            | stagpssgazurepocdev01                            | bicep/storage-stagpssgazurepocdev01.bicep     | [ ]    |
| 16   | Key Vault                  | kv-ag-pssg-azure-files                           | bicep/keyvault-ag-pssg-azure-files.bicep      | [ ]    |
| 17   | Log Analytics Workspace    | law-ag-pssg-azure-files                          | bicep/law-ag-pssg-azure-files.bicep           | [ ]    |
| 18   | User-Assigned MI (optional)| uami-ag-pssg-azure-files                         | bicep/uami-ag-pssg-azure-files.bicep          | [ ]    |
| 19   | Private Endpoint (Storage) | pe-ag-pssg-azure-files-storage                   | bicep/pe-storage.bicep                        | [ ]    |
| 20   | Private Endpoint (KeyVault)| pe-ag-pssg-azure-files-keyvault                  | bicep/pe-keyvault.bicep                       | [ ]    |
| 21   | Foundry                    | foundry-ag-pssg-azure-files                      | bicep/foundry-ag-pssg-azure-files.bicep       | [ ]    |
| 22   | Foundry Project            | foundry-ag-pssg-azure-files-project              | bicep/foundry-project.bicep                   | [ ]    |

> **Note:** Update the script names/paths as you create or refactor your Bicep modules. Some objects (like subnets) may already exist in your landing zone and do not need to be created.
