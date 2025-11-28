// User-Assigned Managed Identity
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'ag-pssg-azure-files-uami'
  location: location
}
