// Azure Document Intelligence MLOps Infrastructure
// This Bicep template creates the necessary Azure resources for Document Intelligence MLOps pipeline

@description('Environment name (dev, qa, prod)')
param environment string = 'dev'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Cognitive Services account name prefix')
param cognitiveServicePrefix string = 'doc-intelligence'

@description('Tags for resources')
param tags object = {
  Environment: environment
  Project: 'DocumentIntelligenceMLOps'
  ManagedBy: 'Bicep'
}

// Generate unique resource names
var cognitiveServiceName = '${cognitiveServicePrefix}-${environment}-${uniqueString(resourceGroup().id)}'
var storageAccountName = 'dimlops${environment}${take(uniqueString(resourceGroup().id), 6)}'
var keyVaultName = 'kv-dimlops-${environment}-${take(uniqueString(resourceGroup().id), 6)}'

// Cognitive Services Account for Document Intelligence
resource cognitiveService 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: cognitiveServiceName
  location: location
  tags: tags
  kind: 'FormRecognizer'
  sku: {
    name: environment == 'prod' ? 'S0' : 'F0' // Free tier for dev/qa, Standard for prod
  }
  properties: {
    customSubDomainName: cognitiveServiceName
    disableLocalAuth: false
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    apiProperties: {}
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Storage Account for model artifacts and backups
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// Blob containers for different purposes
resource modelArtifactsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  name: '${storageAccount.name}/default/model-artifacts'
  properties: {
    publicAccess: 'None'
  }
}

resource backupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  name: '${storageAccount.name}/default/backups'
  properties: {
    publicAccess: 'None'
  }
}

resource testDataContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  name: '${storageAccount.name}/default/test-data'
  properties: {
    publicAccess: 'None'
  }
}

// Key Vault for storing secrets
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
    accessPolicies: []
  }
}

// Store Cognitive Services key in Key Vault
resource cognitiveServiceKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'CognitiveServicesKey'
  properties: {
    value: cognitiveService.listKeys().key1
    contentType: 'text/plain'
  }
}

// Store Storage Account connection string in Key Vault
resource storageConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'StorageConnectionString'
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${az.environment().suffixes.storage}'
    contentType: 'text/plain'
  }
}

// Log Analytics Workspace for Application Insights
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-dimlops-${environment}-${take(uniqueString(resourceGroup().id), 6)}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: environment == 'prod' ? 90 : 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: environment == 'prod' ? 10 : 1
    }
  }
}

// Application Insights for monitoring
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'ai-dimlops-${environment}-${take(uniqueString(resourceGroup().id), 6)}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    RetentionInDays: environment == 'prod' ? 90 : 30
  }
}

// Outputs
output cognitiveServiceName string = cognitiveService.name
output cognitiveServiceEndpoint string = cognitiveService.properties.endpoint
output storageAccountName string = storageAccount.name
output keyVaultName string = keyVault.name
output applicationInsightsName string = applicationInsights.name
output resourceGroupName string = resourceGroup().name
output cognitiveServiceId string = cognitiveService.id
output storageAccountId string = storageAccount.id
