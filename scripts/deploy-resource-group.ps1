# Create the resource group for the landing zone
$resourceGroup = "rg-ag-pssg-azure-files-azure-foundry"
$location = "canadacentral"
az group create --name $resourceGroup --location $location

