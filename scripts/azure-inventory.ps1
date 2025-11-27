# Export all private endpoints for each resource group
Write-Host "Exporting all private endpoints for each resource group..."
$resourceGroups = az group list --query "[].name" -o tsv
foreach ($rg in $resourceGroups) {
    $peFile = "$baseDir/private-endpoints-$rg.txt"
    Write-Host "  - Resource Group: $rg"
    az network private-endpoint list --resource-group $rg --output table > $peFile
}

# Azure Landing Zone Inventory Script
# This script inventories all major Azure resources in the current subscription and outputs results to JSON and table files.
# It will prompt for Azure login and subscription selection if needed.

# Step 1: Login to Azure
Write-Host "Logging in to Azure..."
az login

# Step 2: List subscriptions and prompt user to select
$subs = az account list --query "[].{Name:name, Id:id, IsDefault:isDefault}" -o json | ConvertFrom-Json
Write-Host "\nAvailable Azure Subscriptions:"
for ($i = 0; $i -lt $subs.Count; $i++) {
    $star = if ($subs[$i].IsDefault) { '*' } else { ' ' }
    Write-Host ("[$i]$star $($subs[$i].Name) ($($subs[$i].Id))")
}
$choice = Read-Host "Select a subscription by number (or press Enter for default)"
if ($choice -ne "" -and $choice -match '^[0-9]+$' -and $choice -lt $subs.Count) {
    $subId = $subs[$choice].Id
    az account set --subscription $subId
    Write-Host "Subscription set to: $($subs[$choice].Name) ($subId)"
} else {
    $default = $subs | Where-Object { $_.IsDefault }
    Write-Host "Using default subscription: $($default.Name) ($($default.Id))"
}

# Always use the same output folder
$baseDir = "./azure-inventory"
New-Item -ItemType Directory -Path $baseDir -Force | Out-Null


Write-Host "Exporting all resource groups..."
az group list --output json > "$baseDir/all-resource-groups.json"
az group list --output table > "$baseDir/all-resource-groups.txt"

Write-Host "Exporting all resources..."
az resource list --output json > "$baseDir/all-resources.json"
az resource list --output table > "$baseDir/all-resources.txt"

Write-Host "Exporting all VNets..."
az network vnet list --output json > "$baseDir/all-vnets.json"
az network vnet list --output table > "$baseDir/all-vnets.txt"

Write-Host "Exporting all subnets for each VNet..."
$vnets = az network vnet list --query "[].{Name:name, ResourceGroup:resourceGroup}" -o json | ConvertFrom-Json
foreach ($vnet in $vnets) {
    $rg = $vnet.ResourceGroup
    $name = $vnet.Name
    $outFile = "$baseDir/subnets-$rg-$name.txt"
    az network vnet subnet list --resource-group $rg --vnet-name $name --output table > $outFile
}

Write-Host "Exporting all storage accounts..."
az storage account list --output json > "$baseDir/all-storage-accounts.json"
az storage account list --output table > "$baseDir/all-storage-accounts.txt"

Write-Host "Exporting all containers and file shares for each storage account..."
$accounts = az storage account list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json
foreach ($acct in $accounts) {
    $acctName = $acct.name
    $acctRG = $acct.resourceGroup
    $containerFile = "$baseDir/containers-$acctName.txt"
    $shareFile = "$baseDir/fileshares-$acctName.txt"
    Write-Host "  - Storage Account: $acctName (Resource Group: $acctRG)"
    az storage container list --account-name $acctName --resource-group $acctRG --output table > $containerFile
    az storage share list --account-name $acctName --resource-group $acctRG --output table > $shareFile
}

Write-Host "Exporting all VMs..."
az vm list --output json > "$baseDir/all-vms.json"
az vm list --output table > "$baseDir/all-vms.txt"

Write-Host "Exporting all Bastion hosts..."
az network bastion list --output json > "$baseDir/all-bastions.json"
az network bastion list --output table > "$baseDir/all-bastions.txt"

Write-Host "Exporting all Private DNS zones..."
az network private-dns zone list --output json > "$baseDir/all-private-dns-zones.json"
az network private-dns zone list --output table > "$baseDir/all-private-dns-zones.txt"


Write-Host "Exporting all NSGs..."
az network nsg list --output json > "$baseDir/all-nsgs.json"
az network nsg list --output table > "$baseDir/all-nsgs.txt"

# Export inbound and outbound security rules for each NSG
$nsgs = az network nsg list --query "[].{Name:name, ResourceGroup:resourceGroup}" -o json | ConvertFrom-Json
foreach ($nsg in $nsgs) {
    $nsgName = $nsg.Name
    $nsgRG = $nsg.ResourceGroup
    $inboundFile = "$baseDir/nsg-$nsgRG-$nsgName-inbound-rules.txt"
    $outboundFile = "$baseDir/nsg-$nsgRG-$nsgName-outbound-rules.txt"
    Write-Host "Exporting inbound rules for NSG: $nsgName in $nsgRG"
    az network nsg rule list --resource-group $nsgRG --nsg-name $nsgName --direction Inbound --output table > $inboundFile
    Write-Host "Exporting outbound rules for NSG: $nsgName in $nsgRG"
    az network nsg rule list --resource-group $nsgRG --nsg-name $nsgName --direction Outbound --output table > $outboundFile
}

Write-Host "Exporting all role assignments for current user..."
$myId = az ad signed-in-user show --query id -o tsv
az role assignment list --assignee $myId --output json > "$baseDir/role-assignments.json"
az role assignment list --assignee $myId --output table > "$baseDir/role-assignments.txt"

# Export Azure AI Foundry related resources
Write-Host "Exporting Azure Machine Learning workspaces..."
az ml workspace list --output json > "$baseDir/all-ml-workspaces.json"
az ml workspace list --output table > "$baseDir/all-ml-workspaces.txt"

Write-Host "Exporting Azure Cognitive Services accounts..."
az cognitiveservices account list --output json > "$baseDir/all-cognitive-services.json"
az cognitiveservices account list --output table > "$baseDir/all-cognitive-services.txt"

Write-Host "Exporting Azure OpenAI resources..."
az cognitiveservices account list --kind OpenAI --output json > "$baseDir/all-openai-accounts.json"
az cognitiveservices account list --kind OpenAI --output table > "$baseDir/all-openai-accounts.txt"

Write-Host "\nInventory complete. All outputs are in $baseDir."
