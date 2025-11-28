// Log Analytics Workspace
resource law 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'ag-pssg-azure-files-law'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}
