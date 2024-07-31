targetScope = 'subscription'

@description('The Azure region for the resources')
param location string = 'japaneast'

@description('The IP prefix for the virtual network')
param ipPrefix string = '10.99'

@description('The name of the storage account')
param storageAccountName string = 'acadifytest'

@description('The name of the storage account container')
param storageAccountContainerName string = 'dfy'

@description('The name of the Redis cache')
param redisName string = 'acadifyredis'

@description('The name of the PostgreSQL flexible server')
param postgresName string = 'acadifypsql'

@description('The PostgreSQL administrator username')
param postgresAdminUsername string = 'user'

@description('The PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('The name of the ACA environment')
param acaEnvName string = 'dify-aca-env'

@description('The name of the Log Analytics workspace')
param logAnalyticsName string = 'dify-loga'

@description('The base64-encoded content of the ACA certificate')
@secure()
param acaCertContent string

@description('The password for the ACA certificate')
@secure()
param acaCertPassword string

@description('The custom domain for Dify')
param acaDifyCustomerDomain string = 'dify.nikadwang.com'

@description('The Dify API image')
param difyApiImage string = 'langgenius/dify-api:0.6.11'

@description('The Dify sandbox image')
param difySandboxImage string = 'langgenius/dify-sandbox:0.2.1'

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${location}'
  location: location
}

// Virtual Network
module vnet './modules/vnet.bicep' = {
  scope: rg
  name: 'vnetDeployment'
  params: {
    location: location
    ipPrefix: ipPrefix
  }
}

// PostgreSQL
module postgres './modules/postgresql.bicep' = {
  scope: rg
  name: 'postgresDeployment'
  params: {
    location: location
    serverName: postgresName
    administratorLogin: postgresAdminUsername
    administratorLoginPassword: postgresAdminPassword
    subnetId: vnet.outputs.postgresSubnetId
  }
}

// Redis Cache
module redis './modules/redis.bicep' = {
  scope: rg
  name: 'redisDeployment'
  params: {
    location: location
    redisName: redisName
    subnetId: vnet.outputs.privateLinkSubnetId
  }
}

// Storage Account
module storage './modules/storage.bicep' = {
  scope: rg
  name: 'storageDeployment'
  params: {
    location: location
    storageAccountName: storageAccountName
    containerName: storageAccountContainerName
  }
}

// ACA Environment
module aca './modules/aca.bicep' = {
  scope: rg
  name: 'acaDeployment'
  params: {
    location: location
    acaEnvName: acaEnvName
    logAnalyticsName: logAnalyticsName
    subnetId: vnet.outputs.acaSubnetId
    storageAccountName: storage.outputs.storageAccountName
    storageAccountKey: storage.outputs.storageAccountKey
    redisHostName: redis.outputs.redisHostName
    redisAccessKey: redis.outputs.redisAccessKey
    postgresHost: postgres.outputs.postgresHost
    postgresAdminUsername: postgresAdminUsername
    postgresAdminPassword: postgresAdminPassword
    acaCertContent: acaCertContent
    acaCertPassword: acaCertPassword
    acaDifyCustomerDomain: acaDifyCustomerDomain
    difyApiImage: difyApiImage
    difySandboxImage: difySandboxImage
  }
}

output postgresHost string = postgres.outputs.postgresHost
output redisHostName string = redis.outputs.redisHostName
output storageAccountName string = storage.outputs.storageAccountName
