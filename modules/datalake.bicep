targetScope = 'resourceGroup'

param suffix string
param location string = resourceGroup().location
param sapdmdatalake_name string 
param synapse_azure_ad_admin_object_id string
param containerNames array 

resource sapdatalake 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: '${sapdmdatalake_name}${suffix}'
  location: location
  sku: {
    name: 'Standard_RAGRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    isHnsEnabled: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource sapdatalakeBlobService 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = {
  parent: sapdatalake
  name: 'default'
}

// Create containers if specified
resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = [for containerName in containerNames: {
  parent: sapdatalakeBlobService
  name: !empty(containerNames) ? '${sapdatalake.name}/default/${toLower(containerName)}' : '${sapdatalake.name}/default/sap'
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}]

resource synapseStorageUserPermissions 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(sapdatalake.id, subscription().subscriptionId)
  scope: sapdatalake
  properties: {
    principalId: synapse_azure_ad_admin_object_id
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  }
}

// Outputs for reference in the Post-Deployment Configuration
output sapdatalakeDFS string = sapdatalake.properties.primaryEndpoints.dfs
output datalake_name string = sapdatalake.name
