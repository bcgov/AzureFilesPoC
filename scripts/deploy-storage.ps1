# Deploy Storage Account
$resourceGroup = "rg-ag-pssg-azure-files-azure-foundry"
$location = "canadacentral"
az deployment group create --resource-group $resourceGroup --template-file "../bicep/storage-stagpssgazurepocdev01.bicep" --parameters location=$location

