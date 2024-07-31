param location string
param acaEnvName string
param logAnalyticsName string
param subnetId string
param storageAccountName string
@secure()
param storageAccountKey string
param redisHostName string
@secure()
param redisAccessKey string
param postgresHost string
param postgresAdminUsername string
@secure()
param postgresAdminPassword string
@secure()
param acaCertContent string
@secure()
param acaCertPassword string
param acaDifyCustomerDomain string
param difyApiImage string
param difySandboxImage string

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource acaEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: acaEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: subnetId
    }
  }
}

resource nginxStorage 'Microsoft.App/managedEnvironments/storages@2022-03-01' = {
  parent: acaEnvironment
  name: 'nginxshare'
  properties: {
    azureFile: {
      accountName: storageAccountName
      accountKey: storageAccountKey
      shareName: 'nginx'
      accessMode: 'ReadWrite'
    }
  }
}

resource ssrfProxyStorage 'Microsoft.App/managedEnvironments/storages@2022-03-01' = {
  parent: acaEnvironment
  name: 'ssrfproxyfileshare'
  properties: {
    azureFile: {
      accountName: storageAccountName
      accountKey: storageAccountKey
      shareName: 'ssrfproxy'
      accessMode: 'ReadWrite'
    }
  }
}

resource sandboxStorage 'Microsoft.App/managedEnvironments/storages@2022-03-01' = {
  parent: acaEnvironment
  name: 'sandbox'
  properties: {
    azureFile: {
      accountName: storageAccountName
      accountKey: storageAccountKey
      shareName: 'sandbox'
      accessMode: 'ReadWrite'
    }
  }
}

resource acaCertificate 'Microsoft.App/managedEnvironments/certificates@2022-03-01' = {
  parent: acaEnvironment
  name: 'difycerts'
  properties: {
    password: acaCertPassword
    value: acaCertContent
  }
}

resource nginxApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'nginx'
  location: location
  properties: {
    managedEnvironmentId: acaEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
        customDomains: [
          {
            name: acaDifyCustomerDomain
            certificateId: acaCertificate.id
          }
        ]
      }
    }
    template: {
      containers: [
        {
          name: 'nginx'
          image: 'nginx:latest'
          resources: {
            cpu: '0.5'
            memory: '1Gi'
          }
          volumeMounts: [
            {
              mountPath: '/etc/nginx'
              volumeName: 'nginxconf'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 10
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
      volumes: [
        {
          name: 'nginxconf'
          storageName: nginxStorage.name
          storageType: 'AzureFile'
        }
      ]
    }
  }
}

resource ssrfProxyApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'ssrfproxy'
  location: location
  properties: {
    managedEnvironmentId: acaEnvironment.id
    configuration: {
      ingress: {
        external: false
        targetPort: 3128
        transport: 'auto'
      }
    }
    template: {
      containers: [
        {
          name: 'ssrfproxy'
          image: 'ubuntu/squid:latest'
          resources: {
            cpu: '0.5'
            memory: '1Gi'
          }
          volumeMounts: [
            {
              mountPath: '/etc/squid'
              volumeName: 'ssrfproxy'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 10
        rules: [
          {
            name: 'tcp-rule'
            tcp: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
      volumes: [
        {
          name: 'ssrfproxy'
          storageName: ssrfProxyStorage.name
          storageType: 'AzureFile'
        }
      ]
    }
  }
}

resource sandboxApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'sandbox'
  location: location
  properties: {
    managedEnvironmentId: acaEnvironment.id
    configuration: {
      ingress: {
        external: false
        targetPort: 8194
        transport: 'tcp'
      }
    }
    template: {
      containers: [
        {
          name: 'langgenius'
          image: difySandboxImage
          resources: {
            cpu: '0.5'
            memory: '1Gi'
          }
          env: [
            {
              name: 'API_KEY'
              value: 'dify-sandbox'
            }
            {
              name: 'GIN_MODE'
              value: 'release'
            }
            {
              name: 'WORKER_TIMEOUT'
              value: '15'
            }
            {
              name: 'ENABLE_NETWORK'
              value: 'true'
            }
            {
              name: 'HTTP_PROXY'
              value: 'http://ssrfproxy:3128'
            }
            {
              name: 'HTTPS_PROXY'
              value: 'http://ssrfproxy:3128'
            }
            {
              name: 'SANDBOX_PORT'
              value: '8194'
            }
          ]
          volumeMounts: [
            {
              mountPath: '/dependencies'
              volumeName: 'sandbox'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 10
        rules: [
          {
            name: 'tcp-rule'
            tcp: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
      volumes: [
        {
          name: 'sandbox'
          storageName: sandboxStorage.name
          storageType: 'AzureFile'
        }
      ]
    }
  }
}

resource workerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'worker'
  location: location
  properties: {
    managedEnvironmentId: acaEnvironment.id
    configuration: {
      secrets: [
        {
          name: 'postgres-password'
          value: postgresAdminPassword
        }
        {
          name: 'redis-password'
          value: redisAccessKey
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'langgenius'
          image: difyApiImage
          resources: {
            cpu: 2
            memory: '4Gi'
          }
          env: [
            {
              name: 'MODE'
              value: 'worker'
            }
            {
              name: 'LOG_LEVEL'
              value: 'INFO'
            }
            {
              name: 'SECRET_KEY'
              value: 'sk-9f73s3ljTXVcMT3Blb3ljTqtsKiGHXVcMT3BlbkFJLK7U'
            }
            {
              name: 'DB_USERNAME'
              value: postgresAdminUsername
            }
            {
              name: 'DB_PASSWORD'
              secretRef: 'postgres-password'
            }
            {
              name: 'DB_HOST'
              value: postgresHost
            }
            {
              name: 'DB_PORT'
              value: '5432'
            }
            {
              name: 'DB_DATABASE'
              value: 'difypgsqldb'
            }
            {
              name: 'REDIS_HOST'
              value: redisHostName
            }
            {
              name: 'REDIS_PORT'
              value: '6379'
            }
            {
              name: 'REDIS_PASSWORD'
              secretRef: 'redis-password'
            }
            {
              name: 'REDIS_USE_SSL'
              value: 'false'
            }
            {
              name: 'REDIS_DB'
              value: '0'
            }
            {
              name: 'CELERY_BROKER_URL'
              value: 'redis://:${redisAccessKey}@${redisHostName}:6379/1'
            }
            {
              name: 'STORAGE_TYPE'
              value: 'azure-blob'
            }
            {
              name: 'AZURE_BLOB_ACCOUNT_NAME'
              value: storageAccountName
            }
            {
              name: 'AZURE_BLOB_ACCOUNT_KEY'
              value: storageAccountKey
            }
            {
              name: 'AZURE_BLOB_ACCOUNT_URL'
              value: 'https://${storageAccountName}.blob.core.windows.net'
            }
            {
              name: 'AZURE_BLOB_CONTAINER_NAME'
              value: 'dfy'
            }
            {
              name: 'VECTOR_STORE'
              value: 'pgvector'
            }
            {
              name: 'PGVECTOR_HOST'
              value: postgresHost
            }
            {
              name: 'PGVECTOR_PORT'
              value: '5432'
            }
            {
              name: 'PGVECTOR_USER'
              value: postgresAdminUsername
            }
            {
              name: 'PGVECTOR_PASSWORD'
              secretRef: 'postgres-password'
            }
            {
              name: 'PGVECTOR_DATABASE'
              value: 'pgvector'
            }
            {
              name: 'INDEXING_MAX_SEGMENTATION_TOKENS_LENGTH'
              value: '1000'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
        rules: [
          {
            name: 'tcp-rule'
            tcp: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

resource apiApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'api'
  location: location
  properties: {
    managedEnvironmentId: acaEnvironment.id
    configuration: {
      ingress: {
        external: false
        targetPort: 5001
        transport: 'tcp'
      }
      secrets: [
        {
          name: 'postgres-password'
          value: postgresAdminPassword
        }
        {
          name: 'redis-password'
          value: redisAccessKey
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'langgenius'
          image: difyApiImage
          resources: {
            cpu: 2
            memory: '4Gi'
          }
          env: [
            {
              name: 'MODE'
              value: 'api'
            }
            {
              name: 'LOG_LEVEL'
              value: 'INFO'
            }
            {
              name: 'SECRET_KEY'
              value: 'sk-9f73s3ljTXVcMT3Blb3ljTqtsKiGHXVcMT3BlbkFJLK7U'
            }
            {
              name: 'DB_USERNAME'
              value: postgresAdminUsername
            }
            {
              name: 'DB_PASSWORD'
              secretRef: 'postgres-password'
            }
            {
              name: 'DB_HOST'
              value: postgresHost
            }
            {
              name: 'DB_PORT'
              value: '5432'
            }
            {
              name: 'DB_DATABASE'
              value: 'difypgsqldb'
            }
            {
              name: 'REDIS_HOST'
              value: redisHostName
            }
            {
              name: 'REDIS_PORT'
              value: '6379'
            }
            {
              name: 'REDIS_PASSWORD'
              secretRef: 'redis-password'
            }
            {
              name: 'REDIS_USE_SSL'
              value: 'false'
            }
            {
              name: 'REDIS_DB'
              value: '0'
            }
            {
              name: 'CELERY_BROKER_URL'
              value: 'redis://:${redisAccessKey}@${redisHostName}:6379/1'
            }
            {
              name: 'STORAGE_TYPE'
              value: 'azure-blob'
            }
            {
              name: 'AZURE_BLOB_ACCOUNT_NAME'
              value: storageAccountName
            }
            {
              name: 'AZURE_BLOB_ACCOUNT_KEY'
              value: storageAccountKey
            }
            {
              name: 'AZURE_BLOB_ACCOUNT_URL'
              value: 'https://${storageAccountName}.blob.core.windows.net'
            }
            {
              name: 'AZURE_BLOB_CONTAINER_NAME'
              value: 'dfy'
            }
            {
              name: 'VECTOR_STORE'
              value: 'pgvector'
            }
            {
              name: 'PGVECTOR_HOST'
              value: postgresHost
            }
            {
              name: 'PGVECTOR_PORT'
              value: '5432'
            }
            {
              name: 'PGVECTOR_USER'
              value: postgresAdminUsername
            }
            {
              name: 'PGVECTOR_PASSWORD'
              secretRef: 'postgres-password'
            }
            {
              name: 'PGVECTOR_DATABASE'
              value: 'pgvector'
            }
            {
              name: 'CODE_EXECUTION_API_KEY'
              value: 'dify-sandbox'
            }
            {
              name: 'CODE_EXECUTION_ENDPOINT'
              value: 'http://sandbox:8194'
            }
            {
              name: 'SSRF_PROXY_HTTP_URL'
              value: 'http://ssrfproxy:3128'
            }
            {
              name: 'SSRF_PROXY_HTTPS_URL'
              value: 'http://ssrfproxy:3128'
            }
            {
              name: 'INDEXING_MAX_SEGMENTATION_TOKENS_LENGTH'
              value: '1000'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 10
        rules: [
          {
            name: 'tcp-rule'
            tcp: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

resource webApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'web'
  location: location
  properties: {
    managedEnvironmentId: acaEnvironment.id
    configuration: {
      ingress: {
        external: false
        targetPort: 3000
        transport: 'tcp'
      }
    }
    template: {
      containers: [
        {
          name: 'langgenius'
          image: 'langgenius/dify-web:0.6.11'
          resources: {
            cpu: 1
            memory: '2Gi'
          }
          env: [
            {
              name: 'CONSOLE_API_URL'
              value: ''
            }
            {
              name: 'APP_API_URL'
              value: ''
            }
            {
              name: 'SENTRY_DSN'
              value: ''
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 10
        rules: [
          {
            name: 'tcp-rule'
            tcp: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}
