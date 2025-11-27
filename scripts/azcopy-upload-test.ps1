# azcopy-upload-test.ps1
# Uploads a test file to the specified Azure Blob container using AzCopy and a SAS URL

param(
    [string]$FilePath = "azcopy-test-upload.txt",
    [string]$SasUrl = "https://stagpssgazurepocdev01.blob.core.windows.net/blob-ag-pssg-azure-files-poc-dev-01?sp=racwdl&st=2025-11-12T19:38:47Z&se=2025-11-13T03:53:47Z&sip=108.172.9.11&spr=https&sv=2024-11-04&sr=c&sig=NQB0y%2FK2YHIFKulCp8XqeB2kOBnuwUH88fdCtLeQj9o%3D"
)

# Create a test file if it doesn't exist
if (-not (Test-Path $FilePath)) {
    "This is a test file for AzCopy upload. Created on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')." | Out-File -Encoding utf8 $FilePath
    Write-Host "Created test file: $FilePath"
} else {
    Write-Host "Using existing file: $FilePath"
}

# Upload the file using AzCopy
azcopy copy $FilePath $SasUrl

if ($LASTEXITCODE -eq 0) {
    Write-Host "Upload succeeded."
} else {
    Write-Host "Upload failed with exit code $LASTEXITCODE."
}
