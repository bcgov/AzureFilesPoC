# VM Auto-Shutdown & Manual Shutdown Guidance

## Why This Matters
Azure VMs accrue billable hours while running. Shutting down VMs when not in use saves costs.

## Manual Shutdown Script (Recommended)
Run this script to stop your VM when you are done:

```powershell
# Stop the VM (deallocates and stops billing)
az vm stop --name YOUR-VM-NAME --resource-group YOUR-RESOURCE-GROUP
```

```powershell
az vm stop --name vm-ag-pssg-azure-files-01 --resource-group rg-ag-pssg-azure-files-azure-foundry
```

## To fully stop billing and deallocate a VM
```powershell
az vm deallocate --name vm-ag-pssg-azure-files-01 --resource-group rg-ag-pssg-azure-files-azure-foundry
az network bastion delete --name bastion-ag-pssg-azure-files --resource-group rg-ag-pssg-azure-files-azure-foundry
```


- Replace `YOUR-VM-NAME` and `YOUR-RESOURCE-GROUP` with your actual values.
- This command deallocates the VM and stops billing for compute resources.

## How to Check VM Status
```powershell
az vm show --name YOUR-VM-NAME --resource-group YOUR-RESOURCE-GROUP --query "powerState" -o tsv
```
- Output should be `VM deallocated` when stopped.

## Auto-Shutdown Feature (Azure Portal)
You can also enable auto-shutdown in the Azure Portal:
1. Go to your VM resource.
2. In the left menu, select **Auto-shutdown**.
3. Set a daily shutdown time (e.g., 7:00 PM).
4. Save the configuration.

- This will automatically stop the VM at the scheduled time every day.
- You can receive email notifications before shutdown.

## Best Practice
- Always stop/deallocate VMs when not in use.
- Use auto-shutdown for unattended cost control.
- Restart the VM when you need it again:

```powershell
az vm start --name YOUR-VM-NAME --resource-group YOUR-RESOURCE-GROUP
```

## Reference
- [Azure VM Auto-shutdown Documentation](https://learn.microsoft.com/en-us/azure/virtual-machines/auto-shutdown)
- [Azure VM Billing FAQ](https://learn.microsoft.com/en-us/azure/virtual-machines/billing)
