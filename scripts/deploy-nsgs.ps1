# Deploy NSGs for VM, Bastion, and PE subnets
$resourceGroup = "rg-ag-pssg-azure-files-azure-foundry"
$location = "canadacentral"

az deployment group create --resource-group $resourceGroup --template-file "../bicep/nsg-ag-pssg-azure-files-azure-foundry.bicep" --parameters location=$location
az deployment group create --resource-group $resourceGroup --template-file "../bicep/nsg-ag-pssg-azure-files-azure-foundry-bastion.bicep" --parameters location=$location
az deployment group create --resource-group $resourceGroup --template-file "../bicep/nsg-ag-pssg-azure-files-azure-foundry-pe.bicep" --parameters location=$location


