# Filename: scripts/bicep/deploy-resource-group.ps1
# Create the resource group for the landing zone using variables from azure.env
# Always use the project root azure.env
$envPath = Join-Path $PSScriptRoot "..\..\azure.env"
if (Test-Path $envPath) {
	Get-Content $envPath | ForEach-Object {
		if ($_ -match '^(\w+)="?([^"]+)"?$') {
			$name, $value = $matches[1], $matches[2]
			Set-Variable -Name $name -Value $value -Scope Script
		}
	}
} else {
	Write-Error "azure.env file not found at $envPath"
	exit 1
}

$resourceGroup = $env:RG_AZURE_FILES
$location = $env:TARGET_AZURE_REGION
if (-not $resourceGroup) { $resourceGroup = $RG_AZURE_FILES }
if (-not $location) { $location = $TARGET_AZURE_REGION }


# Idempotent resource group creation
$existing = az group show --name $resourceGroup --query "name" -o tsv 2>$null
if ($existing -eq $resourceGroup) {
	Write-Host "Resource group '$resourceGroup' already exists. Skipping creation."
} else {
	Write-Host "Resource group '$resourceGroup' does not exist. Creating..."
	az group create --name $resourceGroup --location $location | Out-Null
}

# Confirm creation
$confirmed = az group show --name $resourceGroup --query "name" -o tsv 2>$null
if ($confirmed -eq $resourceGroup) {
	Write-Host "Resource group '$resourceGroup' confirmed present."
} else {
	Write-Error "Resource group '$resourceGroup' could not be created or found."
	exit 1
}

