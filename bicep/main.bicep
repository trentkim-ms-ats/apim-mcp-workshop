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
@allowed(['Y1', 'EP1', 'EP2', 'EP3'])
param functionPlanSku string = 'Y1'

@description('Entra ID 테넌트 ID')
param tenantId string = subscription().tenantId

@description('배포 타임스탬프')
param deploymentTimestamp string = utcNow('yyyyMMddHHmmss')

// ============================================================
// 변수 정의
// ============================================================

var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 6)
var namingPrefix = '${prefix}-${environment}'

var resourceNames = {
  apim: '${namingPrefix}-apim-${uniqueSuffix}'
  functionApp: '${namingPrefix}-func-${uniqueSuffix}'
  appServicePlan: '${namingPrefix}-asp-${uniqueSuffix}'
  storageAccount: 'st${prefix}${environment}${uniqueSuffix}'
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
// Storage Account (Functions용)
// ============================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: resourceNames.storageAccount
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

// ============================================================
// App Service Plan (Functions용)
// ============================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: resourceNames.appServicePlan
  location: location
  tags: tags
  sku: {
    name: functionPlanSku
  }
  kind: 'functionapp'
  properties: {
    reserved: true // Linux
  }
}

// ============================================================
// Azure Functions App
// ============================================================

resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: resourceNames.functionApp
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.12'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(resourceNames.functionApp)
        }
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
    resourceId: 'https://management.azure.com${functionApp.id}'
    credentials: {
      header: {
        'x-functions-key': ['{{functions-key}}']
      }
    }
  }
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
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output appInsightsName string = appInsights.name
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output resourceGroupName string = resourceGroup().name
output apimPrincipalId string = apim.identity.principalId
output functionPrincipalId string = functionApp.identity.principalId
