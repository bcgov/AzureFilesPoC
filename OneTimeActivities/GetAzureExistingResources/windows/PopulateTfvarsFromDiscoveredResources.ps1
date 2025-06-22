# PopulateTfvarsFromDiscoveredResources.ps1
# Reads .env/azure_full_inventory.json to populate terraform.tfvars and secrets.tfvars (PowerShell variant)
# Usage: .\PopulateTfvarsFromDiscoveredResources.ps1

param()

Set-StrictMode -Version Latest

# Resolve paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = Resolve-Path "$ScriptDir\..\..\.."
$EnvDir = Join-Path $ProjectRoot ".env"
$TerraformValidationDir = Join-Path $ProjectRoot "terraform/validation"

$InventoryJson = Join-Path $EnvDir "azure_full_inventory.json"
$CredentialsJson = Join-Path $EnvDir "azure-credentials.json"
$TfvarsTemplate = Join-Path $TerraformValidationDir "terraform.tfvars.template"
$SecretsTemplate = Join-Path $TerraformValidationDir "secrets.tfvars.template"
$TfvarsFile = Join-Path $TerraformValidationDir "terraform.tfvars"
$SecretsFile = Join-Path $TerraformValidationDir "secrets.tfvars"

if (!(Test-Path $InventoryJson)) { Write-Error "$InventoryJson not found. Run azure_full_inventory.ps1 first."; exit 1 }
if (!(Test-Path $TfvarsTemplate)) { Write-Error "$TfvarsTemplate not found."; exit 1 }
if (!(Test-Path $SecretsTemplate)) { Write-Error "$SecretsTemplate not found."; exit 1 }
if (!(Test-Path $CredentialsJson)) { Write-Error "$CredentialsJson not found."; exit 1 }

# Helper: Extract value from JSON
function JqGet($json, $query) {
    $value = $json | Select-Object -ExpandProperty $query -ErrorAction SilentlyContinue
    if ($null -eq $value) { return "" } else { return $value }
}

# Load JSON
$inv = Get-Content $InventoryJson | ConvertFrom-Json
$cred = Get-Content $CredentialsJson | ConvertFrom-Json

# Extract values
$subscriptionId = $cred.azure.subscription.id
$resourceGroup = $inv.resourceGroups | Where-Object { $_.tags } | Select-Object -First 1 -ExpandProperty name
if (-not $resourceGroup) { $resourceGroup = $inv.resourceGroups[0].name }
$location = ($inv.resourceGroups | Where-Object { $_.name -eq $resourceGroup } | Select-Object -ExpandProperty location)
if (-not $location) { $location = $inv.virtualNetworks[0].location }
$vnetName = $inv.virtualNetworks[0].name
$vnetId = $inv.virtualNetworks[0].id
$vnetAddressSpace = $inv.virtualNetworks[0].addressSpace[0]
$dnsServers = $inv.virtualNetworks[0].dnsServers[0]
$subnetName = $inv.virtualNetworks[0].subnets[0].name
$subnetAddressPrefixes = $inv.virtualNetworks[0].subnets[0].addressPrefix
$storageAccountName = $inv.storageAccounts[0].name
$fileShareName = $inv.fileShares[0].name

# Tags
$accountCoding = ($inv.resources | Where-Object { $_.type -eq 'Microsoft.Network/virtualNetworks' } | Select-Object -First 1).tags.account_coding
$billingGroup = ($inv.resources | Where-Object { $_.type -eq 'Microsoft.Network/virtualNetworks' } | Select-Object -First 1).tags.billing_group
$ministryName = ($inv.resources | Where-Object { $_.type -eq 'Microsoft.Network/virtualNetworks' } | Select-Object -First 1).tags.ministry_name
$owner = ($inv.resources | Where-Object { $_.type -eq 'Microsoft.Network/networkSecurityGroups' } | Select-Object -First 1).tags.owner
$project = ($inv.resources | Where-Object { $_.type -eq 'Microsoft.Network/networkSecurityGroups' } | Select-Object -First 1).tags.project
$environment = ($inv.resources | Where-Object { $_.type -eq 'Microsoft.Network/networkSecurityGroups' } | Select-Object -First 1).tags.environment

# Populate terraform.tfvars
(Get-Content $TfvarsTemplate) | ForEach-Object {
    $_ -replace 'subscription_name = ".*"', "subscription_name = \"$subscriptionName\"" `
      -replace 'subscription_id = ".*"', "subscription_id = \"$subscriptionId\"" `
      -replace 'resource_group = ".*"', "resource_group = \"$resourceGroup\"" `
      -replace 'location = ".*"', "location = \"$location\"" `
      -replace 'storage_account_name = ".*"', "storage_account_name = \"$storageAccountName\"" `
      -replace 'file_share_name = ".*"', "file_share_name = \"$fileShareName\"" `
      -replace 'vnet_name = ".*"', "vnet_name = \"$vnetName\"" `
      -replace 'vnet_id = ".*"', "vnet_id = \"$vnetId\"" `
      -replace 'vnet_address_space = \[".*"\]', "vnet_address_space = [\"$vnetAddressSpace\"]" `
      -replace 'dns_servers = ".*"', "dns_servers = \"$dnsServers\"" `
      -replace 'subnet_name = ".*"', "subnet_name = \"$subnetName\"" `
      -replace 'subnet_address_prefixes = \[".*"\]', "subnet_address_prefixes = [\"$subnetAddressPrefixes\"]" `
      -replace 'account_coding  = ".*"', "  account_coding  = \"$accountCoding\"" `
      -replace 'billing_group   = ".*"', "  billing_group   = \"$billingGroup\"" `
      -replace 'ministry_name   = ".*"', "  ministry_name   = \"$ministryName\"" `
      -replace 'owner           = ".*"', "  owner           = \"$owner\"" `
      -replace 'project         = ".*"', "  project         = \"$project\"" `
      -replace 'environment     = ".*"', "  environment     = \"$environment\""
} | Set-Content $TfvarsFile

# Populate secrets.tfvars
$clientId = $cred.azure.ad.application.clientId
$tenantId = $cred.azure.ad.tenantId
$subscriptionId = $cred.azure.subscription.id
(Get-Content $SecretsTemplate) | ForEach-Object {
    $_ -replace '# client_id.*', "client_id       = \"$clientId\"  # App Registration's Application (client) ID" `
      -replace '# client_secret.*', "# client_secret   = \"<not needed for OIDC/GitHub Actions>\" # See OIDC documentation for details" `
      -replace '# tenant_id.*', "tenant_id       = \"$tenantId\"  # Your Azure AD tenant ID" `
      -replace '# subscription_id.*', "subscription_id = \"$subscriptionId\"  # Your Azure subscription ID"
} | Set-Content $SecretsFile

Write-Host "Populated: $TfvarsFile and $SecretsFile from $InventoryJson and $CredentialsJson"
