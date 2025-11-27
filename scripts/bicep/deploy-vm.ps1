# Deploy VM (legacy or non-LZ compliant)
# Edit the variables below as needed before running.

$resourceGroup = "rg-ag-pssg-azure-files-poc-dev"
$location = "canadacentral"
$vmName = "myvm01"
$sshPublicKey = Read-Host "Enter your SSH public key (single line)"

az deployment group create --resource-group $resourceGroup --template-file "../../bicep/vm-lz-compliant.bicep" --parameters vmName=$vmName sshPublicKey="$sshPublicKey" location=$location
