#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Upload files to Azure Blob Storage using a user delegation SAS token.

.DESCRIPTION
    This script generates a short-lived (1 hour) user delegation SAS token and uploads
    files to the temp-ai-test container in stagpssgazurepocdev01 storage account.
    
    Prerequisites:
    - Azure CLI installed and logged in (az login)
    - Your IP must be in the storage account's allowed IP list
    - azcopy installed

.PARAMETER FilePath
    Path to the file to upload. Defaults to examples\sample-document.txt

.EXAMPLE
    .\upload-to-blob.ps1
    .\upload-to-blob.ps1 -FilePath ".\mydocument.txt"
#>

param(
    [string]$FilePath = ".\examples\sample-document.txt",
    [string]$StorageAccount = "stagpssgazurepocdev01",
    [string]$ContainerName = "temp-ai-test"
)

# Verify file exists
if (-not (Test-Path $FilePath)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

$FileName = Split-Path $FilePath -Leaf
Write-Host "Uploading: $FileName to $ContainerName" -ForegroundColor Cyan

# Generate SAS token (1 hour expiry, using storage account key)
Write-Host "Generating SAS token (valid for 1 hour)..." -ForegroundColor Yellow
$EXPIRY = (Get-Date).AddHours(1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Get storage account key
$STORAGE_KEY = az storage account keys list `
    --account-name $StorageAccount `
    --resource-group rg-ag-pssg-azure-files-azure-foundry `
    --query "[0].value" -o tsv

if (-not $STORAGE_KEY) {
    Write-Error "Failed to get storage account key. Make sure you have access."
    exit 1
}

$SAS = az storage container generate-sas `
    --account-name $StorageAccount `
    --name $ContainerName `
    --permissions rwdl `
    --expiry $EXPIRY `
    --account-key $STORAGE_KEY `
    --https-only `
    -o tsv

if (-not $SAS) {
    Write-Error "Failed to generate SAS token. Make sure you're logged in (az login) and your IP is allowed."
    exit 1
}

Write-Host "SAS token generated. Expiry: $EXPIRY" -ForegroundColor Green

# Build destination URL
$DestUrl = "https://$StorageAccount.blob.core.windows.net/$ContainerName/$FileName`?$SAS"

# Upload with azcopy
Write-Host "Uploading with azcopy..." -ForegroundColor Yellow
azcopy copy $FilePath $DestUrl

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Upload successful!" -ForegroundColor Green
    Write-Host "`nTo download on VM, run:" -ForegroundColor Cyan
    Write-Host "az storage blob download --account-name $StorageAccount --container-name $ContainerName --name $FileName --file ~/examples/$FileName --auth-mode login"
} else {
    Write-Error "Upload failed. Check the azcopy log for details."
    exit 1
}
