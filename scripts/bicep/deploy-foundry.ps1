# Deploy Foundry Resource
$resourceGroup = "rg-ag-pssg-azure-files-azure-foundry"
$location = "canadacentral"
az deployment group create --resource-group $resourceGroup --template-file "../../bicep/foundry-ag-pssg-azure-files.bicep" --parameters location=$location
