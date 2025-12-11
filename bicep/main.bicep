// ============================================================
// Azure APIM + MCP 서버 워크샵 - 메인 Bicep 템플릿
// ============================================================

targetScope = 'resourceGroup'

@description('배포 리전')
param location string = resourceGroup().location

@description('리소스 네이밍 접두사')
param prefix string = 'mcp'

@description('환경 (dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'

@description('APIM SKU')
@allowed(['Basicv2', 'Standardv2', 'Developer'])
param apimSku string = 'Basicv2'

@description('APIM 용량')
param apimCapacity int = 1

@description('Functions App Service Plan SKU')
@allowed(['EP1', 'EP2', 'EP3'])
param functionPlanSku string = 'EP1'

@description('Entra ID 테넌트 ID')
param tenantId string = subscription().tenantId

@description('기존 Storage Account 이름 (사전 생성된 경우)')
param existingStorageAccountName string

@description('배포 타임스탬프')
param deploymentTimestamp string = utcNow('yyyyMMddHHmmss')

// ============================================================
// 변수 정의
// ============================================================

var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 4)
var namingPrefix = '${prefix}-${environment}'

var resourceNames = {
  apim: '${namingPrefix}-apim-${uniqueSuffix}'
  functionApp: '${namingPrefix}-func-${uniqueSuffix}'
  appServicePlan: '${namingPrefix}-asp-${uniqueSuffix}'
  storageAccount: existingStorageAccountName
  appInsights: '${namingPrefix}-ai-${uniqueSuffix}'
  logAnalytics: '${namingPrefix}-law-${uniqueSuffix}'
}

var tags = {
  Environment: environment
  Project: 'APIM-MCP-Workshop'
  ManagedBy: 'Bicep'
  DeployedAt: deploymentTimestamp
}

// ============================================================
// Log Analytics Workspace
// ============================================================

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: resourceNames.logAnalytics
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// ============================================================
// Application Insights
// ============================================================

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: resourceNames.appInsights
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ============================================================
// Storage Account (기존 리소스 참조)
// ============================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: existingStorageAccountName
}

// ============================================================
// App Service Plan (Functions용)
// ============================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: resourceNames.appServicePlan
  location: location
  tags: tags
  sku: {
    name: functionPlanSku
    tier: 'ElasticPremium'
    size: functionPlanSku
    family: 'EP'
    capacity: 1
  }
  kind: 'elastic'
  properties: {
    reserved: true // Linux
    maximumElasticWorkerCount: 20
  }
}

// ============================================================
// Azure Functions App
// ============================================================

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: resourceNames.functionApp
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    reserved: true
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    siteConfig: {
      linuxFxVersion: 'Python|3.12'
      appSettings: [
        // AzureWebJobsStorage: Managed Identity 사용 (Azure Files 미사용)
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccount.name
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        // 참고: WEBSITE_CONTENTAZUREFILECONNECTIONSTRING 미설정
        // Azure Files를 사용하지 않으면 Shared Key가 불필요함
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'MCP_PROTOCOL_VERSION'
          value: '2024-11-05'
        }
        {
          name: 'MCP_SERVER_NAME'
          value: 'Azure-MCP-Functions-Server'
        }
      ]
      cors: {
        allowedOrigins: ['*']
      }
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }
}

// ============================================================
// Storage Account에 Functions Managed Identity 권한 부여
// ============================================================

// Azure 기본 제공 역할 정의
// 참조: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles
var storageBlobDataOwnerRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
var storageAccountContributorRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab')
var storageQueueDataContributorRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
var storageTableDataContributorRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
// 참고: Azure Files를 사용하지 않으므로 Storage File Data SMB Share Contributor 역할 불필요

// Functions App에 Storage Blob Data Owner 역할 부여 (코드 저장)
resource functionStorageBlobRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, functionApp.id, storageBlobDataOwnerRole)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageBlobDataOwnerRole
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Functions App에 Storage Account Contributor 역할 부여 (관리)
resource functionStorageAccountRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, functionApp.id, storageAccountContributorRole)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageAccountContributorRole
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Functions App에 Storage Queue Data Contributor 역할 부여 (런타임)
resource functionStorageQueueRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, functionApp.id, storageQueueDataContributorRole)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageQueueDataContributorRole
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Functions App에 Storage Table Data Contributor 역할 부여 (런타임)
resource functionStorageTableRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, functionApp.id, storageTableDataContributorRole)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageTableDataContributorRole
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// 참고: Azure Files를 사용하지 않으므로 Storage File Data SMB Share Contributor 역할 불필요

// ============================================================
// API Management
// ============================================================

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: resourceNames.apim
  location: location
  tags: tags
  sku: {
    name: apimSku
    capacity: apimCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: 'admin@example.com'
    publisherName: 'MCP Workshop'
    notificationSenderEmail: 'apimgmt-noreply@mail.windowsazure.com'
  }
}

// ============================================================
// APIM Logger (Application Insights 연동)
// ============================================================

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2023-05-01-preview' = {
  parent: apim
  name: 'app-insights-logger'
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: appInsights.properties.InstrumentationKey
    }
    isBuffered: true
    resourceId: appInsights.id
  }
}

// ============================================================
// APIM Named Value (Functions Key)
// ============================================================
// 참고: 초기 배포 시 임시 값 사용, 배포 후 실제 키로 업데이트

resource apimNamedValueFunctionsKey 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  parent: apim
  name: 'functions-key'
  properties: {
    displayName: 'functions-key'
    secret: true
    value: 'temporary-key-will-be-updated-after-deployment'
  }
}

// ============================================================
// APIM Diagnostic Settings
// ============================================================

resource apimDiagnostics 'Microsoft.ApiManagement/service/diagnostics@2023-05-01-preview' = {
  parent: apim
  name: 'applicationinsights'
  properties: {
    loggerId: apimLogger.id
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    verbosity: 'information'
    logClientIp: true
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        headers: []
        body: {
          bytes: 8192
        }
      }
      response: {
        headers: []
        body: {
          bytes: 8192
        }
      }
    }
    backend: {
      request: {
        headers: []
        body: {
          bytes: 8192
        }
      }
      response: {
        headers: []
        body: {
          bytes: 8192
        }
      }
    }
  }
}

// ============================================================
// APIM Backend (Functions 연동)
// ============================================================

resource apimBackend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  parent: apim
  name: 'mcp-functions-backend'
  properties: {
    title: 'MCP Functions Backend'
    description: 'Azure Functions MCP Server'
    protocol: 'http'
    url: 'https://${functionApp.properties.defaultHostName}/api'
    resourceId: '${az.environment().resourceManager}${functionApp.id}'
    credentials: {
      header: {
        'x-functions-key': ['{{functions-key}}']
      }
    }
  }
  dependsOn: [
    apimNamedValueFunctionsKey
  ]
}

// ============================================================
// APIM API (MCP)
// ============================================================

resource apimMcpApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apim
  name: 'mcp-api'
  properties: {
    displayName: 'MCP Server API'
    description: 'Model Context Protocol Server API'
    path: 'mcp'
    protocols: ['https']
    serviceUrl: 'https://${functionApp.properties.defaultHostName}/api/mcp'
    subscriptionRequired: true
    type: 'http'
    format: 'openapi+json'
    value: loadTextContent('../src/mcp-function/openapi.json')
  }
}

// ============================================================
// Outputs
// ============================================================

output apimName string = apim.name
output apimGatewayUrl string = apim.properties.gatewayUrl
output functionAppName string = functionApp.name
output functionAppId string = functionApp.id
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output storageAccountName string = storageAccount.name
output appInsightsName string = appInsights.name
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output resourceGroupName string = resourceGroup().name
output apimPrincipalId string = apim.identity.principalId
output functionPrincipalId string = functionApp.identity.principalId
