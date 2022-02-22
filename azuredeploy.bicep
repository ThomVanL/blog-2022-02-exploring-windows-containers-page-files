targetScope='resourceGroup'

@description('Your IP')
param yourIp string

@description('Virtual Machine administrator username')
param vmAdminUsername string

@secure()
@description('Virtual Machine administrator password')
param vmAdminPassword string

@description('The name of the Windows container image we want to build')
param acrImageName string = 'wcowpagefiles:latest'

@description('The location for all resources in this deployment.')
param deploymentLocation string = resourceGroup().location

@description('URL to the .git file')
param acrTaskRunSourceLocation string = 'https://github.com/ThomVanL/blog-2022-02-exploring-windows-containers-page-files.git#main:WincontainersPageFiles-app'

@description('URL to the Initialize-WinContainersVm.ps1 script')
param vmSetupScriptLocation string = 'https://raw.githubusercontent.com/ThomVanL/blog-2022-02-exploring-windows-containers-page-files/main/scripts/Initialize-WinContainersVm.ps1'

var vmSkus = [
  'Standard_D4s_v3'
  'Standard_E4-2s_v4'
]

var uniqueishSuffix = uniqueString(resourceGroup().id)

resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: format('tvlacr{0}', substring(uniqueishSuffix, 0, 5))
  location: deploymentLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: true
  }
}

resource acr_build_from_github_task 'Microsoft.ContainerRegistry/registries/taskRuns@2019-06-01-preview' = {
  name: 'buildAndPush'
  parent: acr
  location: deploymentLocation
  properties: {
    runRequest: {
      agentConfiguration: {
        cpu: 2
      }
      type: 'DockerBuildRequest'
      sourceLocation: acrTaskRunSourceLocation
      dockerFilePath: 'Dockerfile'
      arguments: [
        {
          name: 'SOURCE'
          value: './WincontainersPageFiles-app/'
        }
      ]
      platform: {
        os: 'Windows'
        architecture: 'amd64'
      }
      imageNames: [
        acrImageName
      ]
      isPushEnabled: true
    }
  }
}

resource aci 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: 'tvl-aci'
  location: deploymentLocation
  dependsOn: [
    acr_build_from_github_task
  ]
  properties: {
    osType: 'Windows'
    sku: 'Standard'
    imageRegistryCredentials: [
      {
        username: acr.listCredentials().username
        password: acr.listCredentials().passwords[0].value
        server: acr.properties.loginServer
      }
    ]
    ipAddress:{
      type: 'Public'
      dnsNameLabel: 'tvlaci${uniqueishSuffix}'
      ports: [
       {
         port: 80
         protocol: 'TCP'
       }
      ]
    }
    containers: [
      {
        name: 'tvl-blog-windowscontainerspagefiles'
        properties: {
          image: format('{0}/{1}', acr.properties.loginServer, acrImageName)
          resources: {
            requests: {
              cpu: 2
              memoryInGB: 8
            }
            limits: {
              cpu: 2
              memoryInGB: 8
            }
          }
          ports: [
            {
              port: 80
              protocol: 'TCP'
            }
          ]
        }
      }
    ]
  }
}

resource app_service_plan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: 'tvl-asp'
  location: deploymentLocation
  sku: {
    tier: 'PremiumV3'
    name: 'P1V3'
  }
  kind: 'windows'
  properties: {
    hyperV: true
  }
}

resource app_service 'Microsoft.Web/sites@2021-02-01' = {
  name: 'tvl-wcow-page-files-${uniqueishSuffix}'
  location: deploymentLocation
  dependsOn: [
    acr_build_from_github_task
  ]
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: format('https://{0}', acr.properties.loginServer)
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: acr.listCredentials().username
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: acr.listCredentials().passwords[0].value
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          // This is really as much memory as you can request on a single container with a P1V3
          name: 'WEBSITE_MEMORY_LIMIT_MB'
          value: '4000'
        }
      ]
      windowsFxVersion: format('DOCKER|{0}/{1}', acr.properties.loginServer, acrImageName)
      use32BitWorkerProcess: false
      alwaysOn: true
    }
    serverFarmId: app_service_plan.id
    clientAffinityEnabled: false
  }
}

resource default_sn_nsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'tvl-vm-nsg'
  location: deploymentLocation
  properties: {
    securityRules: [
      {
        name: 'Allow_Inbound_Rdp_IpRange'
        properties: {
          description: 'RDP'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: yourIp
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'tvl-vnet'
  location: deploymentLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: default_sn_nsg.id
          }
        }
      }
    ]
  }
}

resource vm_pips 'Microsoft.Network/publicIPAddresses@2021-05-01' = [for (sku, i) in vmSkus: {
  name: format('tvl-vm-{0:D3}-pip', i)
  location: deploymentLocation
  sku: {
    tier: 'Regional'
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}]

resource vm_nics 'Microsoft.Network/networkInterfaces@2021-05-01' = [for (sku, i) in vmSkus: {
  name: format('tvl-vm-{0:D3}-nic', i)
  location: deploymentLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: vm_pips[i].id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
  }
}]

resource vms 'Microsoft.Compute/virtualMachines@2021-07-01' = [for (sku, i) in vmSkus: {
  name: format('tvl-vm-{0:D3}', i)
  location: deploymentLocation
  properties: {
    osProfile: {
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
      computerName: format('tvl-vm-{0:D3}', i)
    }
    hardwareProfile: {
      vmSize: sku
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vm_nics[i].id
        }
      ]
    }
    storageProfile: {
      imageReference: {
        publisher: 'microsoftvisualstudio'
        offer: 'visualstudio2022'
        sku: 'vs-2022-comm-latest-ws2022'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        deleteOption: 'Detach'
        name: format('tvl-vm-{0:D3}-os-{1:D3}', i, 1)
      }
    }
  }
}]

resource vms_setupscript 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = [for (sku, i) in vmSkus: {
  name: 'Initialize-WinContainersVm'
  parent: vms[i]
  location: deploymentLocation
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      skipDos2Unix: false
    }
    protectedSettings: {
      fileUris: [
        vmSetupScriptLocation
      ]
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File "Initialize-WinContainersVm.ps1"'
    }
  }
}]
