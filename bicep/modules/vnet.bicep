param location string
param ipPrefix string

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-${location}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '${ipPrefix}.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'PrivateLinkSubnet'
        properties: {
          addressPrefix: '${ipPrefix}.1.0/24'
        }
      }
      {
        name: 'ACASubnet'
        properties: {
          addressPrefix: '${ipPrefix}.16.0/20'
          delegations: [
            {
              name: 'aca-delegation'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'PostgresSubnet'
        properties: {
          addressPrefix: '${ipPrefix}.2.0/24'
          delegations: [
            {
              name: 'postgres-delegation'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output privateLinkSubnetId string = vnet.properties.subnets[0].id
output acaSubnetId string = vnet.properties.subnets[1].id
output postgresSubnetId string = vnet.properties.subnets[2].id
