<#
    Deploy Private Endpoint Subnet in Existing VNet using Bicep and azure.env
    
    KNOWN ISSUE: This script hangs during deployment due to PowerShell output buffering.
    
    Use the manual az command below instead:
    
    az deployment group create `
      --resource-group d5007d-dev-networking `
      --template-file C:\Users\RICHFREM\source\repos\AzureFilesPoC\bicep\subnet-create.bicep `
      --parameters vnetName=d5007d-dev-vwan-spoke `
                   vnetResourceGroup=d5007d-dev-networking `
                   subnetName=snet-ag-pssg-azure-files-pe `
                   addressPrefix=10.46.73.128/27 `
                   nsgResourceId="/subscriptions/d321bcbe-c5e8-4830-901c-dab5fab3a834/resourceGroups/rg-ag-pssg-azure-files-azure-foundry/providers/Microsoft.Network/networkSecurityGroups/nsg-ag-pssg-azure-files-azure-foundry-pe" `
                   isPrivateEndpointSubnet=true
    
    The manual command completes in ~4-5 seconds.
    This script is kept for reference only until the PowerShell issue is resolved.
#>

Write-Warning "This script has a known issue and will hang. Please use the manual az command in the script header."
exit 1
