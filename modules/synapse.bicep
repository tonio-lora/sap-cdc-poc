targetScope = 'resourceGroup'

param suffix string
param location string
param sap_dm_synapse_workspace string
param synapse_sql_administrator_login string
param synapse_sql_administrator_login_password string
param sapdatalakeDFS string
param datalake_name string
param containerNames array
param synapse_IR_SAP_name string



resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: '${sap_dm_synapse_workspace}${suffix}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    defaultDataLakeStorage: {
      accountUrl: sapdatalakeDFS
      filesystem: containerNames[0]
    }
    encryption: {
    }
    sqlAdministratorLogin: synapse_sql_administrator_login
    sqlAdministratorLoginPassword: synapse_sql_administrator_login_password
    publicNetworkAccess: 'Enabled'
  }
}


resource workspaces_sap_dm_synapse_name_allowAll 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  parent: synapseWorkspace
  name: 'allowAll'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

resource synapseStorageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' existing = {
  name: datalake_name
}

resource synapseStorageWorkspacePermissions 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(synapseWorkspace.id, subscription().subscriptionId, 'Contributor')
  scope: synapseStorageAccount
  properties: {
    principalId: synapseWorkspace.identity.principalId
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  }
}


resource synapse_IR_AZURE 'Microsoft.Synapse/workspaces/integrationruntimes@2021-06-01' = {
  parent: synapseWorkspace
  name: 'IR-AZURE'
  properties: {
    type: 'Managed'
    typeProperties: {
      computeProperties: {
        location: 'AutoResolve'
        dataFlowProperties: {
          computeType: 'MemoryOptimized'
          coreCount: 32
          timeToLive: 30
        }
      }
    }
  }
}

resource synapse_IR_SAP 'Microsoft.Synapse/workspaces/integrationruntimes@2021-06-01' = {
  parent: synapseWorkspace
  name: synapse_IR_SAP_name
  properties: {
    type: 'SelfHosted'
    typeProperties: {
    }
  }
}


output synapse_analytics_workspace_name string = synapseWorkspace.name
