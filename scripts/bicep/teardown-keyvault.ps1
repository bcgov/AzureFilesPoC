# Filename: scripts/bicep/teardown-keyvault.ps1
# Teardown Key Vault
# This script removes the Key Vault created for the AI Foundry Landing Zone

# Load environment variables
$envFile = Join-Path $PSScriptRoot "..\..\azure.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
    Write-Host "Environment variables loaded from azure.env" -ForegroundColor Green
} else {
    Write-Host "azure.env file not found at $envFile" -ForegroundColor Red
    exit 1
}

# Variables
$resourceGroup = $env:RG_AZURE_FILES
$keyVault = $env:KEYVAULT_NAME
$location = $env:AZURE_LOCATION

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Tearing Down Key Vault" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup"
Write-Host "Key Vault: $keyVault"
Write-Host ""

# Check if Key Vault exists
Write-Host "Checking if Key Vault exists..." -ForegroundColor Yellow
$kv = az keyvault show `
    --name $keyVault `
    --resource-group $resourceGroup `
    --query "id" `
    --output tsv 2>$null

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($kv)) {
    Write-Host "Key Vault '$keyVault' does not exist. Checking soft-deleted vaults..." -ForegroundColor Yellow
    
    # Check if it's soft-deleted
    $deletedKv = az keyvault list-deleted `
        --query "[?name=='$keyVault'].id" `
        --output tsv 2>$null
    
    if ([string]::IsNullOrEmpty($deletedKv)) {
        Write-Host "Key Vault '$keyVault' not found (active or soft-deleted). Nothing to remove." -ForegroundColor Yellow
        exit 0
    } else {
        Write-Host "Key Vault '$keyVault' is soft-deleted. Will purge it." -ForegroundColor Yellow
        $needsPurge = $true
    }
} else {
    Write-Host "Key Vault found: $kv" -ForegroundColor Green
    $needsPurge = $false
}

# Confirm deletion
Write-Host ""
Write-Host "⚠️  WARNING: This will delete the Key Vault and ALL its secrets." -ForegroundColor Red
Write-Host "All secrets, keys, and certificates will be permanently deleted." -ForegroundColor Red
if ($needsPurge) {
    Write-Host "The vault will be PURGED immediately (no soft-delete recovery)." -ForegroundColor Red
} else {
    Write-Host "The vault will be soft-deleted (recoverable for 90 days unless purged)." -ForegroundColor Yellow
}
$confirmation = Read-Host "Type 'yes' to confirm deletion"

if ($confirmation -ne 'yes') {
    Write-Host "Deletion cancelled." -ForegroundColor Yellow
    exit 0
}

if (-not $needsPurge) {
    # Delete Key Vault (soft-delete)
    Write-Host ""
    Write-Host "Deleting Key Vault '$keyVault'..." -ForegroundColor Yellow
    az keyvault delete `
        --name $keyVault `
        --resource-group $resourceGroup

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Key Vault '$keyVault' deleted successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "📝 Note: The vault is soft-deleted and can be recovered within 90 days." -ForegroundColor Yellow
        
        # Ask if user wants to purge immediately
        Write-Host ""
        $purgeNow = Read-Host "Do you want to purge the vault immediately? (yes/no)"
        
        if ($purgeNow -eq 'yes') {
            $needsPurge = $true
        } else {
            Write-Host ""
            Write-Host "To purge later, use:" -ForegroundColor Yellow
            Write-Host "az keyvault purge --name $keyVault --location $location" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "Teardown Complete" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            exit 0
        }
    } else {
        Write-Host ""
        Write-Host "❌ Failed to delete Key Vault. Check error messages above." -ForegroundColor Red
        exit 1
    }
}

if ($needsPurge) {
    # Purge Key Vault
    Write-Host ""
    Write-Host "Purging Key Vault '$keyVault'..." -ForegroundColor Yellow
    az keyvault purge `
        --name $keyVault `
        --location $location

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Key Vault '$keyVault' purged successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "❌ Failed to purge Key Vault. Check error messages above." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Teardown Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
