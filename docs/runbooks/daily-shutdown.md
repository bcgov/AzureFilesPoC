# Daily Shutdown Runbook

Quick reference for stopping Azure resources at the end of the day to save costs.

## Quick Shutdown (TL;DR)

```powershell
.\scripts\stop-azure-resources.ps1
```

This deallocates the VM and deletes Bastion, saving approximately **$170/month** when not in use.

---

## Why Shut Down Daily?

| Resource | Running Cost | Stopped Cost | Monthly Savings |
|----------|--------------|--------------|-----------------|
| VM (B2s) | ~$30/month | ~$5/month (disk only) | $25 |
| Bastion | ~$140/month | $0 (deleted) | $140 |
| **Total** | ~$170/month | ~$5/month | **$165** |

> **Note:** The VM is **deallocated** (not deleted), so your disk, data, and configuration are preserved. Bastion is deleted and recreated on startup since it has no persistent state.

---

## Step 1: Run the Stop Script

From your local machine (PowerShell):

```powershell
.\scripts\stop-azure-resources.ps1
```

**What it does:**
1. Deallocates the VM (stops billing for compute, keeps disk)
2. Deletes Azure Bastion and its public IP
3. Verifies final status

**Expected output:**
```
==========================================
Stopping Azure Resources
==========================================
Resource Group: rg-ag-pssg-azure-files-azure-foundry
VM Name: vm-ag-pssg-azure-files-01
Bastion: bastion-ag-pssg-azure-files

Checking current resource status...
   VM Status: VM running
   Bastion: Exists

==========================================
[1/2] Deallocating VM
==========================================
Deallocating VM (keeps disk, stops compute billing)...
VM deallocated successfully!

==========================================
[2/2] Deleting Bastion
==========================================
Calling: teardown-bastion.ps1
...
==========================================
Resources Stopped!
==========================================
Final Status:
   VM: Deallocated (not billing)
   Bastion: Deleted (not billing)

To restart tomorrow:
  .\scripts\start-azure-resources.ps1
```

---

## Step 2: Verify Resources Are Stopped

### Check VM Status
```powershell
az vm get-instance-view `
  --name vm-ag-pssg-azure-files-01 `
  --resource-group rg-ag-pssg-azure-files-azure-foundry `
  --query "instanceView.statuses[1].displayStatus" -o tsv
```
**Expected:** `VM deallocated`

### Check Bastion Status
```powershell
az network bastion show `
  --name bastion-ag-pssg-azure-files `
  --resource-group rg-ag-pssg-azure-files-azure-foundry 2>$null
```
**Expected:** Error (resource not found) - this means it was deleted successfully.

---

## Manual Shutdown (Alternative)

If you prefer to run commands manually:

### Deallocate VM Only
```powershell
az vm deallocate `
  --name vm-ag-pssg-azure-files-01 `
  --resource-group rg-ag-pssg-azure-files-azure-foundry
```

### Delete Bastion Only
```powershell
# Delete Bastion
az network bastion delete `
  --name bastion-ag-pssg-azure-files `
  --resource-group rg-ag-pssg-azure-files-azure-foundry

# Delete Bastion public IP
az network public-ip delete `
  --name pip-bastion-ag-pssg-azure-files `
  --resource-group rg-ag-pssg-azure-files-azure-foundry
```

---

## Next Morning

To restart resources, see [Daily Startup Runbook](./daily-startup.md):

```powershell
.\scripts\start-azure-resources.ps1
```

---

## Related Runbooks

- [Daily Startup Runbook](./daily-startup.md) - Start VM and deploy Bastion
- [Bastion Connection Guide](./bastion-connection.md) - Connect to VM via Bastion
- [VM Shutdown](./vm-shutdown.md) - Manual VM management details
- [AI Model Testing Guide](../guides/ai-model-testing.md) - Full AI testing documentation

---

## Scripts Reference

| Script | Location | Purpose |
|--------|----------|---------|
| `stop-azure-resources.ps1` | `scripts/` | Deallocate VM + delete Bastion |
| `start-azure-resources.ps1` | `scripts/` | Start VM + deploy Bastion |
