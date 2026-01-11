targetScope = 'subscription'

@description('Project name (used for resource naming)')
param projectName string = 'ai-inference'

@description('Azure region for deployment')
param location string = 'eastus'

@description('Environment (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string = 'prod'

@description('Admin email for API Management')
param adminEmail string = 'admin@example.com'

@description('VM SKU for GPU instances')
param vmssSkuName string = 'Standard_NC4as_T4_v3'

@description('Minimum VMSS instances')
param vmssMinInstances int = 0

@description('Maximum VMSS instances')
param vmssMaxInstances int = 20

@description('Maximum price for spot instances')
param vmssSpotMaxPrice string = '0.15'

var nameSuffix = uniqueString(subscription().subscriptionId, projectName, environment)
var tags = {
  project: projectName
  environment: environment
  managedBy: 'bicep'
}

// Resource names
var resourceGroupName = '${projectName}-${environment}-rg'
var keyVaultName = '${projectName}-kv-${nameSuffix}'
var storageAccountName = '${replace(projectName, '-', '')}st${nameSuffix}'
var cosmosAccountName = '${projectName}-cosmos-${nameSuffix}'
var functionAppName = '${projectName}-func-${nameSuffix}'
var appInsightsName = '${projectName}-insights'
var logAnalyticsName = '${projectName}-logs'
var apimName = '${projectName}-apim'
var vnetName = '${projectName}-vnet'
var vmssName = '${projectName}-gpu'
var servicePlanName = '${projectName}-plan'

// =============================================================================
// Resource Group
// =============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// =============================================================================
// Log Analytics & Application Insights
// =============================================================================

module monitoring 'modules/monitoring.bicep' = {
  scope: rg
  name: 'monitoring-deployment'
  params: {
    location: location
    logAnalyticsName: logAnalyticsName
    appInsightsName: appInsightsName
    tags: tags
  }
}

// =============================================================================
// Key Vault
// =============================================================================

module keyVault 'modules/keyvault.bicep' = {
  scope: rg
  name: 'keyvault-deployment'
  params: {
    location: location
    keyVaultName: keyVaultName
    tags: tags
  }
}

// =============================================================================
// Storage Account
// =============================================================================

module storage 'modules/storage.bicep' = {
  scope: rg
  name: 'storage-deployment'
  params: {
    location: location
    storageAccountName: storageAccountName
    tags: tags
  }
}

// =============================================================================
// Cosmos DB
// =============================================================================

module cosmosDb 'modules/cosmosdb.bicep' = {
  scope: rg
  name: 'cosmosdb-deployment'
  params: {
    location: location
    cosmosAccountName: cosmosAccountName
    keyVaultName: keyVaultName
    tags: tags
  }
  dependsOn: [
    keyVault
  ]
}

// =============================================================================
// Networking
// =============================================================================

module network 'modules/network.bicep' = {
  scope: rg
  name: 'network-deployment'
  params: {
    location: location
    vnetName: vnetName
    vmssName: vmssName
    tags: tags
  }
}

// =============================================================================
// Function App
// =============================================================================

module functionApp 'modules/function-app.bicep' = {
  scope: rg
  name: 'function-app-deployment'
  params: {
    location: location
    functionAppName: functionAppName
    servicePlanName: servicePlanName
    storageAccountName: storageAccountName
    keyVaultName: keyVaultName
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
    tags: tags
  }
  dependsOn: [
    storage
    keyVault
    monitoring
  ]
}

// =============================================================================
// VM Scale Set
// =============================================================================

module vmss 'modules/vmss.bicep' = {
  scope: rg
  name: 'vmss-deployment'
  params: {
    location: location
    vmssName: vmssName
    vmssSkuName: vmssSkuName
    vmssMinInstances: vmssMinInstances
    vmssMaxInstances: vmssMaxInstances
    vmssSpotMaxPrice: vmssSpotMaxPrice
    subnetId: network.outputs.vmssSubnetId
    tags: tags
  }
  dependsOn: [
    network
  ]
}

// =============================================================================
// API Management
// =============================================================================

module apim 'modules/apim.bicep' = {
  scope: rg
  name: 'apim-deployment'
  params: {
    location: location
    apimName: apimName
    publisherName: projectName
    publisherEmail: adminEmail
    functionAppHostname: functionApp.outputs.functionAppHostname
    keyVaultName: keyVaultName
    appInsightsId: monitoring.outputs.appInsightsId
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
    tags: tags
  }
  dependsOn: [
    functionApp
    keyVault
    monitoring
  ]
}

// =============================================================================
// Outputs
// =============================================================================

output resourceGroupName string = rg.name
output location string = location
output keyVaultName string = keyVaultName
output storageAccountName string = storageAccountName
output cosmosAccountName string = cosmosAccountName
output functionAppName string = functionAppName
output functionAppUrl string = functionApp.outputs.functionAppUrl
output vmssName string = vmssName
output apimName string = apimName
output apimGatewayUrl string = apim.outputs.apimGatewayUrl
output apiEndpoint string = '${apim.outputs.apimGatewayUrl}/inference'
output logAnalyticsName string = logAnalyticsName
output appInsightsName string = appInsightsName
