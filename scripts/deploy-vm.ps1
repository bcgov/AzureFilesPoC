# Deploy VM and supporting resources
$resourceGroup = "rg-ag-pssg-azure-files-azure-foundry"
$location = "canadacentral"
$vmName = "vm-ag-pssg-azure-files-01"
$vnetName = "d5007d-dev-vwan-spoke"
$subnetName = "snet-ag-pssg-azure-files-vm"
$sshPublicKey = Read-Host "Enter your SSH public key (single line)"

az deployment group create `
  --resource-group $resourceGroup `
  --template-file "../bicep/vm-lz-compliant.bicep" `
  --parameters vmName=$vmName vnetName=$vnetName subnetName=$subnetName sshPublicKey="$sshPublicKey" location=$location

