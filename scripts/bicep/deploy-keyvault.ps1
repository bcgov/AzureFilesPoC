# Deploy Key Vault
$resourceGroup = "rg-ag-pssg-azure-files-azure-foundry"
$location = "canadacentral"
az deployment group create --resource-group $resourceGroup --template-file "../../bicep/keyvault-ag-pssg-azure-files.bicep" --parameters location=$location
