# Deploy VM using Bicep (Landing Zone Compliant)
# Edit the variables below as needed before running.

$resourceGroup = "rg-ag-pssg-azure-files-poc-dev"   # Target resource group
$location = "canadacentral"
$vmName = "myvm01"
$vnetName = "d5007d-dev-vwan-spoke"
$subnetName = "snet-ag-pssg-azure-files-poc-ai-factory"
$sshPublicKey = Read-Host "Enter your SSH public key (single line)"

# Optional: override other parameters as needed
# $vmSize = "Standard_D2s_v3"
# $adminUsername = "azureuser"
# $tags = "env=dev costCentre=JPSS app=AzureFiles dataSensitivity=ProtectedB"

az deployment group create `
  --resource-group $resourceGroup `
  --template-file "../../bicep/vm-lz-compliant.bicep" `
  --parameters vmName=$vmName vnetName=$vnetName subnetName=$subnetName sshPublicKey="$sshPublicKey" location=$location

Write-Host "\nDeployment complete. Check the Azure Portal or CLI for VM status."
