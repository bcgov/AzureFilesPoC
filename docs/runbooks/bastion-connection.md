
# Bastion Connection Guide

How to securely connect to your VM using Azure Bastion.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Connect via Bastion](#connect-via-bastion)
3. [Troubleshooting](#troubleshooting)
4. [Related Runbooks](#related-runbooks)


## Prerequisites
- Ensure your VM is running:
  
  ```bash
  az vm show --name vm-ag-pssg-azure-files-01 --resource-group rg-ag-pssg-azure-files-azure-foundry --query "powerState" -o tsv
  # If the result is 'VM running', you do NOT need to start it.
  # If the result is 'VM deallocated' or nothing, start it:
  az vm start --name vm-ag-pssg-azure-files-01 --resource-group rg-ag-pssg-azure-files-azure-foundry
  ```
- You must have your SSH private key (e.g., `~/.ssh/id_rsa_azure`) available.
- Azure CLI must be installed and logged in.

## Connect via Bastion


### Using variables (if you have them set):

```bash
az network bastion ssh \
  --name $BASTION_NAME \
  --resource-group $RG_AZURE_FILES \
  --target-resource-id "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RG_AZURE_FILES/providers/Microsoft.Compute/virtualMachines/$VM_NAME" \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa_azure
```
*Connect to your VM using environment variables for Bastion, resource group, subscription, and VM name.*


### Hardcoded example (copy-paste ready):

```bash
az network bastion ssh --name bastion-ag-pssg-azure-files --resource-group rg-ag-pssg-azure-files-azure-foundry --target-resource-id "/subscriptions/d321bcbe-c5e8-4830-901c-dab5fab3a834/resourceGroups/rg-ag-pssg-azure-files-azure-foundry/providers/Microsoft.Compute/virtualMachines/vm-ag-pssg-azure-files-01" --auth-type ssh-key --username azureuser --ssh-key ~/.ssh/id_rsa_azure
```
*Connect to your VM using hardcoded values for Bastion, resource group, subscription, and VM name. Copy and paste directly if you do not use variables.*

## Troubleshooting
- If prompted for a passphrase, enter the one you set when creating your SSH key.
- If you see errors about the SSH key path, verify the file exists at `~/.ssh/id_rsa_azure`.
- If you see errors about Bastion extensions, run:
  ```bash
  az extension add -n bastion
  az extension add -n ssh
  az extension update --name bastion
  az extension update --name ssh
  ```
- If you see `enableTunneling` errors, enable native client support in the Azure Portal under Bastion configuration.

## Related Runbooks

- [VM Shutdown](./vm-shutdown.md) - Stop VM to save costs
- [VM Updates](./vm-updates.md) - Apply security patches

## References

- [Azure Bastion Documentation](https://learn.microsoft.com/en-us/azure/bastion/bastion-overview)
- [Deployment Guide](../guides/deployment-guide.md)
