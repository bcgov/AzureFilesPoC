az deployment group create --resource-group $resourceGroup --template-file "../bicep/bastion-pip.bicep" --parameters location=$location
az deployment group create --resource-group $resourceGroup --template-file "../bicep/bastion-nic.bicep" --parameters location=$location
az deployment group create --resource-group $resourceGroup --template-file "../bicep/bastion.bicep" --parameters location=$location


