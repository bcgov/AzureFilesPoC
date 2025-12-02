// Azure AI Foundry Hub Workspace
// Resource type: Microsoft.MachineLearningServices/workspaces with kind: 'Hub'
// This creates an AI Studio/Foundry Hub for hosting AI models and projects

@description('Name of the Foundry Hub workspace')
param foundryName string

@description('Azure region for Foundry Hub - use canadaeast for LLM availability')
param location string

@description('Resource ID of the Storage Account for workspace storage')
param storageAccountId string

@description('Resource ID of the Key Vault for secrets management (optional - Foundry auto-creates if not provided)')
param keyVaultId string = ''

@description('Resource ID of the User-Assigned Managed Identity (optional - uses system identity if not provided)')
param uamiId string = ''

@description('Resource ID of Application Insights (optional)')
param applicationInsightsId string = ''

@description('BC Gov Azure resource tags')
param tags object = {
  account_coding: '105150471019063011500000'
  billing_group: 'd5007d'
  ministry_name: 'AG'
  owner: 'ag-pssg-teams'
  project: 'ag-pssg-azure-files-poc'
}

// Azure AI Foundry Hub (ML Workspace with kind='Hub')
resource foundryHub 'Microsoft.MachineLearningServices/workspaces@2025-06-01' = {
  name: foundryName
  location: location
  tags: tags
  kind: 'Hub'
  
  identity: uamiId != '' ? {
    type: 'SystemAssigned,UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  } : {
    type: 'SystemAssigned'
  }
  
  properties: {
    // Description for the workspace
    friendlyName: 'Azure AI Foundry Hub for ${tags.project}'
    description: 'AI Foundry Hub workspace for hosting AI models and endpoints'
    
    // Connected Azure resources
    storageAccount: storageAccountId
    keyVault: keyVaultId != '' ? keyVaultId : null
    applicationInsights: applicationInsightsId != '' ? applicationInsightsId : null
    
    // Public network access - initially enabled, will be disabled with Private Endpoint
    publicNetworkAccess: 'Enabled'
    
    // Primary UAMI for workspace operations (only if UAMI provided)
    primaryUserAssignedIdentity: uamiId != '' ? uamiId : null
    
    // Managed network settings for Hub
    managedNetwork: {
      isolationMode: 'AllowInternetOutbound'  // Can be restricted later
    }
  }
}

// Outputs
output foundryId string = foundryHub.id
output foundryName string = foundryHub.name
output foundryLocation string = foundryHub.location
output foundryWorkspaceId string = foundryHub.properties.workspaceId
output foundryDiscoveryUrl string = foundryHub.properties.discoveryUrl
