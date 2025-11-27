# Deploy Private Endpoints for Storage and Key Vault
$resourceGroup = "rg-ag-pssg-azure-files-azure-foundry"
$location = "canadacentral"
az deployment group create --resource-group $resourceGroup --template-file "../../bicep/pe-storage.bicep" --parameters location=$location
az deployment group create --resource-group $resourceGroup --template-file "../../bicep/pe-keyvault.bicep" --parameters location=$location
