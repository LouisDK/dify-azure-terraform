targetScope = 'subscription'

@description('The Azure region for the resources')
param location string = 'eastus2'

@description('The IP prefix for the virtual network')
param ipPrefix string = '10.99'

@description('The name of the storage account')
param storageAccountName string = 'acansitest'

@description('The name of the storage account container')
param storageAccountContainerName string = 'nsi'

@description('The name of the Redis cache')
param redisName string = 'acansiredis'

@description('The name of the PostgreSQL flexible server')
param postgresName string = 'acansipsql'

@description('The PostgreSQL administrator username')
param postgresAdminUsername string = 'user'

@description('The PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('The name of the ACA environment')
param acaEnvName string = 'nsi-aca-env'

@description('The name of the Log Analytics workspace')
param logAnalyticsName string = 'nsi-loga'

@description('The base64-encoded content of the ACA certificate')
@secure()
param acaCertContent string

@description('The password for the ACA certificate')
@secure()
param acaCertPassword string

@description('The custom domain for NSI')
param acaDifyCustomerDomain string = 'nsidev.netsurit.com'

@description('The Dify API image')
param difyApiImage string = 'langgenius/dify-api:0.6.11'

@description('The Dify sandbox image')
param difySandboxImage string = 'langgenius/dify-sandbox:0.2.1'

@description('The Dify web image')
param difyWebImage string = 'langgenius/dify-web:0.6.11'

@description('The Azure Container Registry name')
param acrName string = ''

@description('The Azure Container Registry login server')
param acrLoginServer string = ''

@description('The Azure Container Registry username')
param acrUsername string = ''

@description('The Azure Container Registry password')
@secure()
param acrPassword string = ''

@description('The deployment environment (dev or prod)')
@allowed([
  'dev'
  'prod'
])
param environment string = 'prod'

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
module postgres './modules/postgresql.bicep' = if (environment == 'prod') {
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
module redis './modules/redis.bicep' = if (environment == 'prod') {
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
    redisHostName: environment == 'prod' ? redis.outputs.redisHostName : ''
    redisAccessKey: environment == 'prod' ? redis.outputs.redisAccessKey : ''
    postgresHost: environment == 'prod' ? postgres.outputs.postgresHost : ''
    postgresAdminUsername: postgresAdminUsername
    postgresAdminPassword: postgresAdminPassword
    acaCertContent: acaCertContent
    acaCertPassword: acaCertPassword
    acaDifyCustomerDomain: acaDifyCustomerDomain
    difyApiImage: difyApiImage
    difySandboxImage: difySandboxImage
    difyWebImage: difyWebImage
    environment: environment
    acrName: acrName
    acrLoginServer: acrLoginServer
    acrUsername: acrUsername
    acrPassword: acrPassword
  }
}

output postgresHost string = environment == 'prod' ? postgres.outputs.postgresHost : 'Using container-based PostgreSQL'
output redisHostName string = environment == 'prod' ? redis.outputs.redisHostName : 'Using container-based Redis'
output storageAccountName string = storage.outputs.storageAccountName
