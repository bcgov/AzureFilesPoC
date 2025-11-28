# Deploy Foundry Project
$resourceGroup = "rg-ag-pssg-azure-files-azure-foundry"
$location = "canadacentral"
az deployment group create --resource-group $resourceGroup --template-file "../../bicep/foundry-project.bicep" --parameters location=$location
