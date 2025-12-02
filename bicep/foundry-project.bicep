// Azure AI Foundry Project
// Projects are workspaces that reference a parent Hub
// Resource type: Microsoft.MachineLearningServices/workspaces with kind: 'Project'

@description('Name of the Foundry Project')
param projectName string

@description('Azure region - must match the Hub location')
param location string

@description('Resource ID of the parent Foundry Hub workspace')
param hubResourceId string

@description('BC Gov Azure resource tags')
param tags object = {
  account_coding: '105150471019063011500000'
  billing_group: 'd5007d'
  ministry_name: 'AG'
  owner: 'ag-pssg-teams'
  project: 'ag-pssg-azure-files-poc'
}

// Azure AI Foundry Project (ML Workspace with kind='Project' and hubResourceId)
resource foundryProject 'Microsoft.MachineLearningServices/workspaces@2025-06-01' = {
  name: projectName
  location: location
  tags: tags
  kind: 'Project'
  
  identity: {
    type: 'SystemAssigned'
  }
  
  properties: {
    // Description
    friendlyName: 'AI Foundry Project for ${tags.project}'
    description: 'Project workspace for deploying and managing AI models'
    
    // Reference to parent Hub - this is what makes it a Project
    hubResourceId: hubResourceId
    
    // Public network access - will inherit from Hub
    publicNetworkAccess: 'Enabled'
  }
}

// Outputs
output projectId string = foundryProject.id
output projectName string = foundryProject.name
output projectWorkspaceId string = foundryProject.properties.workspaceId
output projectDiscoveryUrl string = foundryProject.properties.discoveryUrl
