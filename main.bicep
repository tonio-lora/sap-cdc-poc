/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Azure SAP Accelerator : Bicep Template
//
//    Create a Synapse Analytics environment with a dedicated SQL pool and a data lake storage account
//    and adds Synapse pipelines and other artifacts to showcase SAP CDC capabilities
//
//    Resources:
//
//      Synapse Analytics Workspace:
//          - DW1000 Dedicated SQL Pool
//          - Pipelines to load SAP CDC data into the SQL Pool
//          - Scripts to create brinze, silver and gold views on top of the data lake 
//
//      Azure Data Lake Storage Gen2:
//          - Storage for the Synapse Analytics Workspace configuration data
//          - Storage for the configuration files used by the pipelines
//          - Storage for the data tat will be extracted from SAP
//
//      Integration Runtime VM:
//          - A VM, Disk, and network components to host the Synapse Integration Runtime
//
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

targetScope='subscription'

@description('Region to create all the resources in.')
param location string

@description('Resource Group for all related Azure services.')
param resource_group_name string

@description('Name of the Synapse storage account.')
param sapdmdatalake_name string 

@description('Containers to be created on the Storage account.')
param containerNames array 

@description('Name of the Synapse Workspace.')
param synapse_workspace_name string

@description('Native SQL account for administration.')
param synapse_sql_administrator_login string

@description('Password for the native SQL admin account above.')
@secure()
param synapse_sql_administrator_login_password string

@description('Object ID (GUID) for the Azure AD administrator of Synapse. This can also be a group, but only one value can be specified. (i.e. XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXXXXXXX). "az ad user show --id "anlo@microsoft.com" --query objectId --output tsv"')
param synapse_azure_ad_admin_object_id string

@description('Name of the SAP Integration Runtime to be created.')
param synapse_IR_SAP_name string

@description('Name of the SAP Integration Runtime Virtual Machine to be created.')
param vm_sap_dm_ir_name string

@description('User name of SAP Integration Runtime Virtual Machine')
param ir_vm_adminUsername string

@secure()
@description('Password of SAP Integration Runtime Virtual Machine')
param ir_vm_adminPassword string

@description('NIC name of SAP Integration Runtime Virtual Machine')
param networkInterfaces_sap_ir_name string

@description('Public IP Address of SAP Integration Runtime Virtual Machine')
param publicIPAddress_sap_ir_name string

@description('NSG of SAP Integration Runtime Virtual Machine')
param networkSecurityGroups_sap_ir_name string
// Add a random suffix to ensure global uniqueness among the resources created
var suffix = '${substring(uniqueString(subscription().subscriptionId, deployment().name), 0, 3)}'

// Create the Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: resource_group_name
  location: location
  tags: {
    Environment: 'SAP'
    Application: 'Azure Synapse Analytics'
    Purpose: 'Azure Synapse Analytics SAP CDC Demo'
  }
}

module synapseStorageAccount './modules/datalake.bicep' = {
  name:'datalake'
  scope: resourceGroup
  params: {
    suffix: suffix
    sapdmdatalake_name: sapdmdatalake_name
    location: location
    containerNames: containerNames
    synapse_azure_ad_admin_object_id: synapse_azure_ad_admin_object_id
  }
}

module irVm './modules/integration-runtime.bicep' = {
  name:'irVm'
  scope: resourceGroup
  params: {
    suffix: suffix
    location: location
    vm_sap_dm_ir_name: vm_sap_dm_ir_name
    ir_vm_adminUsername: ir_vm_adminUsername
    ir_vm_adminPassword: ir_vm_adminPassword
    networkInterfaces_sap_ir_name: networkInterfaces_sap_ir_name
    publicIPAddress_sap_ir_name: publicIPAddress_sap_ir_name
    networkSecurityGroups_sap_ir_name: networkSecurityGroups_sap_ir_name
  }
}

module synapse './modules/synapse.bicep' = {
  name:'synapseWorskpace'
  scope: resourceGroup
  params: {
    suffix: suffix
    location: location
    sap_dm_synapse_workspace: '${synapse_workspace_name}${suffix}'
    synapse_sql_administrator_login: synapse_sql_administrator_login
    synapse_sql_administrator_login_password: synapse_sql_administrator_login_password
    sapdatalakeDFS: synapseStorageAccount.outputs.sapdatalakeDFS
    datalake_name: synapseStorageAccount.outputs.datalake_name
    containerNames: containerNames
    synapse_IR_SAP_name: synapse_IR_SAP_name
  }
}
