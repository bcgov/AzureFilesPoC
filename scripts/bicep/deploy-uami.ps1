<#
    Deploy User-Assigned Managed Identity (UAMI)
    
    Purpose:
    - Enables passwordless authentication for VM to access Azure services
    - Used by VM to access Storage Account, Key Vault, and AI Foundry
    - No credentials to manage - Azure handles authentication automatically
    
    Post-Deployment:
    - Assign RBAC roles for this identity on Storage, Key Vault, etc:
      az role assignment create --role "Storage Blob Data Contributor" \
        --assignee <uami-principal-id> \
        --scope /subscriptions/.../resourceGroups/.../providers/Microsoft.Storage/storageAccounts/...
#>

# Load environment variables from azure.env
$envFile = Join-Path $PSScriptRoot "..\..\azure.env"
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        $line = $line.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            if ($line -match '^([^=]+)=(.*)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim() -replace '^"(.*)"$', '$1'
                [Environment]::SetEnvironmentVariable($name, $value, 'Process')
            }
        }
    }
    Write-Host "Loaded environment variables from azure.env" -ForegroundColor Green
} else {
    Write-Error "azure.env file not found at $envFile"
    exit 1
}

# Set variables
$resourceGroup = $env:RG_AZURE_FILES
$location = $env:TARGET_AZURE_REGION
$uamiName = $env:UAMI_NAME

Write-Host "`n=== User-Assigned Managed Identity Deployment ===" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup"
Write-Host "Location: $location"
Write-Host "UAMI: $uamiName`n"

# Check if UAMI already exists
Write-Host "Checking if UAMI '$uamiName' exists..." -ForegroundColor Yellow
$existing = az identity show --name $uamiName --resource-group $resourceGroup --query "name" -o tsv 2>$null

if ($existing -eq $uamiName) {
    Write-Host "UAMI '$uamiName' already exists. Skipping creation." -ForegroundColor Green
    
    # Show details
    $identity = az identity show --name $uamiName --resource-group $resourceGroup | ConvertFrom-Json
    Write-Host "`nUAMI Details:"
    Write-Host "  Principal ID: $($identity.principalId)"
    Write-Host "  Client ID: $($identity.clientId)"
    exit 0
}

# Deploy
$bicepPath = Join-Path $PSScriptRoot "..\..\bicep\uami-ag-pssg-azure-files.bicep"
$deploymentName = "uami-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "Deploying UAMI (this should be quick)..." -ForegroundColor Yellow
Write-Host "Command: az deployment group create --resource-group $resourceGroup --name $deploymentName --template-file $bicepPath --parameters uamiName=$uamiName location=$location`n" -ForegroundColor Gray

$result = az deployment group create --resource-group $resourceGroup --name $deploymentName --template-file $bicepPath --parameters uamiName=$uamiName location=$location

if ($LASTEXITCODE -eq 0) {
    $deployment = $result | ConvertFrom-Json
    $principalId = $deployment.properties.outputs.uamiPrincipalId.value
    $clientId = $deployment.properties.outputs.uamiClientId.value
    
    Write-Host "`nUAMI '$uamiName' created successfully!" -ForegroundColor Green
    Write-Host "`nUAMI Details:"
    Write-Host "  Principal ID: $principalId" -ForegroundColor Cyan
    Write-Host "  Client ID: $clientId" -ForegroundColor Cyan
    
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Assign RBAC roles to grant this identity access to resources:"
    Write-Host "   - Storage Blob Data Contributor (for Storage Account)"
    Write-Host "   - Key Vault Secrets User (for Key Vault)"
    Write-Host "   - Cognitive Services OpenAI User (for AI Foundry)"
    Write-Host "2. Assign this identity to the VM during VM deployment"
    Write-Host "`nExample RBAC assignment:"
    Write-Host "az role assignment create --role 'Storage Blob Data Contributor' --assignee $principalId --scope /subscriptions/$env:AZURE_SUBSCRIPTION_ID/resourceGroups/$resourceGroup/providers/Microsoft.Storage/storageAccounts/$env:STORAGE_ACCOUNT" -ForegroundColor Gray
} else {
    Write-Host "`nDeployment failed!" -ForegroundColor Red
    $result | Write-Host
    exit 1
}


