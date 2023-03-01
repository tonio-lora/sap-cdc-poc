targetScope = 'resourceGroup'

param suffix string
param location string = resourceGroup().location
param vm_sap_dm_ir_name string
param ir_vm_adminUsername string
@secure()
param ir_vm_adminPassword string
param networkInterfaces_sap_ir_name string
param publicIPAddress_sap_ir_name string
param networkSecurityGroups_sap_ir_name string

resource networkInterfaces_sap_ir 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: networkInterfaces_sap_ir_name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        type: 'Microsoft.Network/networkInterfaces/ipConfigurations'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddresses_sap_ir.id
            properties: {
              publicIPAddressVersion: 'IPv4'
              publicIPAllocationMethod: 'Dynamic'
              idleTimeoutInMinutes: 4
              ipTags: []
              deleteOption: 'Detach'
            }
            sku: {
              name: 'Basic'
              tier: 'Regional'
            }
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: true
    enableIPForwarding: false
    disableTcpStateTracking: false
    networkSecurityGroup: {
      id: networkSecurityGroups_sap_ir.id
    }
    nicType: 'Standard'
  }
}

resource virtualMachines_sap_dm_ir_name_resource 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: '${vm_sap_dm_ir_name}${suffix}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2as_v4'
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        name: '${vm_sap_dm_ir_name}_OsDisk_1_${uniqueString(resourceGroup().id)}'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          id: resourceId('Microsoft.Compute/disks', '$${vm_sap_dm_ir_name}_OsDisk_1_${uniqueString(resourceGroup().id)}')
        }
        deleteOption: 'Delete'
      }
      dataDisks: []
    }
    osProfile: {
      computerName: vm_sap_dm_ir_name
      adminUsername: ir_vm_adminUsername
      adminPassword: ir_vm_adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
          enableHotpatching: false
        }
        enableVMAgentPlatformUpdates: false
      }
      secrets: []
      allowExtensionOperations: true
      requireGuestProvisionSignal: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaces_sap_ir.id
          properties: {
            deleteOption: 'Detach'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    licenseType: 'Windows_Server'
    priority: 'Spot'
    evictionPolicy: 'Deallocate'
    billingProfile: {
      maxPrice: -1
    }
  }
}


resource publicIPAddresses_sap_ir 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: publicIPAddress_sap_ir_name
  location: location
  sku: {
    name: 'Basic'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Dynamic'
    idleTimeoutInMinutes: 4
    ipTags: []
  }
}

resource networkSecurityGroups_sap_ir 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: networkSecurityGroups_sap_ir_name
  location: location
  properties: {
    securityRules: [
      {
        name: 'RDP'
        type: 'Microsoft.Network/networkSecurityGroups/securityRules'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
    ]
  }
}

resource networkSecurityGroups_sap_dm_ir_nsg_name_RDP 'Microsoft.Network/networkSecurityGroups/securityRules@2022-07-01' = {
  parent: networkSecurityGroups_sap_ir
  name: 'RDP'
  properties: {
    protocol: 'TCP'
    sourcePortRange: '*'
    destinationPortRange: '3389'
    sourceAddressPrefix: '*'
    destinationAddressPrefix: '*'
    access: 'Allow'
    priority: 300
    direction: 'Inbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
  }
}


