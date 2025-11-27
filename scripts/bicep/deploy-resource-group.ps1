# Deploy Resource Group (if needed)
$resourceGroup = "rg-ag-pssg-azure-files-azure-foundry"
$location = "canadacentral"
az group create --name $resourceGroup --location $location
