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

# Export subscription information
Write-Host "Exporting subscription information..."
az account show --output json > "$baseDir/subscription-info.json"
az account show --output table > "$baseDir/subscription-info.txt"

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

Write-Host "Exporting all public IP addresses..."
az network public-ip list --output json > "$baseDir/all-public-ips.json"
az network public-ip list --output table > "$baseDir/all-public-ips.txt"

Write-Host "Exporting all route tables..."
az network route-table list --output json > "$baseDir/all-route-tables.json"
az network route-table list --output table > "$baseDir/all-route-tables.txt"

Write-Host "Exporting all network watchers..."
az network watcher list --output json > "$baseDir/all-network-watchers.json"
az network watcher list --output table > "$baseDir/all-network-watchers.txt"

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
    try {
        $accountKey = az storage account keys list --account-name $acctName --resource-group $acctRG --query "[0].value" -o tsv
        az storage container list --account-name $acctName --account-key $accountKey --output table > $containerFile
        az storage share list --account-name $acctName --account-key $accountKey --output table > $shareFile
    } catch {
        Write-Host "    Warning: Could not access storage account contents for $acctName (permission denied)"
        "Permission denied - could not list containers/shares" > $containerFile
        "Permission denied - could not list containers/shares" > $shareFile
    }
}

Write-Host "Exporting all Key Vaults..."
az keyvault list --output json > "$baseDir/all-keyvaults.json"
az keyvault list --output table > "$baseDir/all-keyvaults.txt"

# Export Key Vault contents for each vault (may fail due to permissions)
$keyvaults = az keyvault list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json
foreach ($kv in $keyvaults) {
    $kvName = $kv.name
    $kvRG = $kv.resourceGroup
    $secretsFile = "$baseDir/kv-secrets-$kvName.txt"
    $keysFile = "$baseDir/kv-keys-$kvName.txt"
    $certsFile = "$baseDir/kv-certificates-$kvName.txt"
    Write-Host "  - Key Vault: $kvName (Resource Group: $kvRG)"
    try {
        az keyvault secret list --vault-name $kvName --output table > $secretsFile
        az keyvault key list --vault-name $kvName --output table > $keysFile
        az keyvault certificate list --vault-name $kvName --output table > $certsFile
    } catch {
        Write-Host "    Warning: Could not access Key Vault contents for $kvName (permission denied)"
        "Permission denied - could not list secrets" > $secretsFile
        "Permission denied - could not list keys" > $keysFile
        "Permission denied - could not list certificates" > $certsFile
    }
}

Write-Host "Exporting all User Assigned Managed Identities..."
az identity list --output json > "$baseDir/all-user-assigned-identities.json"
az identity list --output table > "$baseDir/all-user-assigned-identities.txt"

Write-Host "Exporting all Log Analytics workspaces..."
az monitor log-analytics workspace list --output json > "$baseDir/all-log-analytics-workspaces.json"
az monitor log-analytics workspace list --output table > "$baseDir/all-log-analytics-workspaces.txt"

Write-Host "Exporting all VMs..."
az vm list --output json > "$baseDir/all-vms.json"
az vm list --output table > "$baseDir/all-vms.txt"

Write-Host "Exporting all VM extensions..."
$vmList = az vm list --query "[].{name:name, resourceGroup:resourceGroup}" -o json | ConvertFrom-Json
foreach ($vm in $vmList) {
    $vmName = $vm.name
    $vmRG = $vm.resourceGroup
    $extFile = "$baseDir/vm-extensions-$vmRG-$vmName.txt"
    Write-Host "  - VM Extensions: $vmName (Resource Group: $vmRG)"
    az vm extension list --resource-group $vmRG --vm-name $vmName --output table > $extFile
}

Write-Host "Exporting all Bastion hosts..."
az network bastion list --output json > "$baseDir/all-bastions.json"
az network bastion list --output table > "$baseDir/all-bastions.txt"

Write-Host "Exporting all Private DNS zones..."
az network private-dns zone list --output json > "$baseDir/all-private-dns-zones.json"
az network private-dns zone list --output table > "$baseDir/all-private-dns-zones.txt"

Write-Host "Exporting all NSGs..."
az network nsg list --output json > "$baseDir/all-nsgs.json"
az network nsg list --output table > "$baseDir/all-nsgs.txt"

# Export security rules for each NSG
$nsgs = az network nsg list --query "[].{Name:name, ResourceGroup:resourceGroup}" -o json | ConvertFrom-Json
foreach ($nsg in $nsgs) {
    $nsgName = $nsg.Name
    $nsgRG = $nsg.ResourceGroup
    $rulesFile = "$baseDir/nsg-$nsgRG-$nsgName-rules.txt"
    Write-Host "Exporting rules for NSG: $nsgName in $nsgRG"
    az network nsg rule list --resource-group $nsgRG --nsg-name $nsgName --output table > $rulesFile
}

Write-Host "Exporting all role assignments for current user..."
$myId = az ad signed-in-user show --query id -o tsv
az role assignment list --assignee $myId --output json > "$baseDir/role-assignments.json"
az role assignment list --assignee $myId --output table > "$baseDir/role-assignments.txt"

Write-Host "Exporting all Azure Policy assignments..."
az policy assignment list --output json > "$baseDir/all-policy-assignments.json"
az policy assignment list --output table > "$baseDir/all-policy-assignments.txt"

# Export Azure AI Foundry related resources
Write-Host "Exporting Azure Machine Learning workspaces..."
try {
    az resource list --resource-type Microsoft.MachineLearningServices/workspaces --output json > "$baseDir/all-ml-workspaces.json"
    az resource list --resource-type Microsoft.MachineLearningServices/workspaces --output table > "$baseDir/all-ml-workspaces.txt"
} catch {
    Write-Host "    Warning: Could not export ML workspaces"
    "Could not query ML workspaces" > "$baseDir/all-ml-workspaces.txt"
}

Write-Host "Exporting Azure Cognitive Services accounts..."
az cognitiveservices account list --output json > "$baseDir/all-cognitive-services.json"
az cognitiveservices account list --output table > "$baseDir/all-cognitive-services.txt"

Write-Host "Exporting Azure OpenAI resources..."
az cognitiveservices account list --query "[?kind=='OpenAI']" --output json > "$baseDir/all-openai-accounts.json"
az cognitiveservices account list --query "[?kind=='OpenAI']" --output table > "$baseDir/all-openai-accounts.txt"

Write-Host "Exporting Azure Monitor alerts..."
az monitor metrics alert list --output json > "$baseDir/all-metric-alerts.json"
az monitor metrics alert list --output table > "$baseDir/all-metric-alerts.txt"

Write-Host "Exporting Azure Monitor diagnostic settings..."
# Note: Diagnostic settings require specific resource - we'll skip this for now as it's complex
Write-Host "    Skipping diagnostic settings export (requires specific resource parameters)"

Write-Host "\nInventory complete. All outputs are in $baseDir."

# Generate summary report
Write-Host "\nGenerating inventory summary..."
& "$PSScriptRoot/azure-inventory-summary.ps1"
