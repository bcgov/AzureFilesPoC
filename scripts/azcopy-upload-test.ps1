# azcopy-upload-test.ps1
# Uploads a test file to the specified Azure Blob container using AzCopy and a SAS URL

param(
    [string]$FilePath = "azcopy-test-upload.txt",
    [string]$SasUrl = "<YOUR_SAS_URL_HERE>" # Provide your SAS URL as a parameter or via environment variable
)

if ($SasUrl -eq '<YOUR_SAS_URL_HERE>') {
    Write-Host "ERROR: Please provide a valid SAS URL as a parameter or set it in the script."
    exit 1
}

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
