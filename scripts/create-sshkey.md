# Windows instructions to create SSH key

## Steps
### 1. Open PowerShell
Press `Win + X`, then select **Windows PowerShell** or **Terminal**.

### 2. Generate a new SSH key pair

**Note:** BC Gov policy requires a passphrase on SSH keys. You will need to enter this passphrase each time you connect via Bastion.

**Option A: With passphrase specified in command:**
```powershell
ssh-keygen -t rsa -b 4096 -C "azure-vm" -f "$env:USERPROFILE\.ssh\id_rsa_azure" -N "YourSecurePassphrase123!"
```

**Option B: Interactive (recommended - prompts for passphrase):**
```powershell
ssh-keygen -t rsa -b 4096 -C "azure-vm" -f "$env:USERPROFILE\.ssh\id_rsa_azure"
```
When prompted, enter a strong passphrase and confirm it.

### 3. Locate your SSH public key
Your public key will be saved as:

```
$env:USERPROFILE\.ssh\id_rsa.pub
```

### 4. Copy the public key contents
Run this command to display your public key:

```powershell
Get-Content $env:USERPROFILE\.ssh\id_rsa.pub
```

Copy the entire output. You will paste this value when prompted by the VM deployment script.

---
**Note:** Never share your private key (`id_rsa`). Only the `.pub` file is safe to share for authentication.


## If need to update ssh key associated with the vm

```powershell
az vm user update --resource-group rg-ag-pssg-azure-files-azure-foundry --name vm-ag-pssg-azure-files-01 --username azureuser --ssh-key-value "<paste-your-public-key-here>"
```

Example:
```powershell
$publicKey = Get-Content "$env:USERPROFILE\.ssh\id_rsa_azure.pub"
az vm user update --resource-group rg-ag-pssg-azure-files-azure-foundry --name vm-ag-pssg-azure-files-01 --username azureuser --ssh-key-value "$publicKey"
```

## How to connect to the vm with bastion

Use the Azure Bastion SSH tunnel feature to connect to your VM:

```powershell
az network bastion ssh --name bastion-ag-pssg-azure-files --resource-group rg-ag-pssg-azure-files-azure-foundry --target-resource-id $(az vm show --name vm-ag-pssg-azure-files-01 --resource-group rg-ag-pssg-azure-files-azure-foundry --query id -o tsv) --auth-type ssh-key --username azureuser --ssh-key "$env:USERPROFILE\.ssh\id_rsa_azure"
```

When prompted, enter the passphrase you set when creating the SSH key.

**Notes:** 
- Make sure you're using the correct private key file (`id_rsa_azure` if you followed the steps above, or `id_rsa` if using your original key)
- If you updated the SSH key using `az vm user update`, it may take a few minutes for the change to propagate. You may need to use your original key until the update completes.
- If connection fails after entering your passphrase, verify which SSH key is actually configured on the VM:
  ```powershell
  az vm show --name vm-ag-pssg-azure-files-01 --resource-group rg-ag-pssg-azure-files-azure-foundry --query "osProfile.linuxConfiguration.ssh.publicKeys[].keyData" --output table
  ```