resource "azurerm_container_app_environment" "cae" {
  name                       = "${var.project}-${var.env}-cae"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  tags                       = var.tags
}

resource "azurerm_user_assigned_identity" "api" {
  name                = "${var.project}-${var.env}-api-mi"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags
}

# Let the API managed identity read Key Vault secrets
resource "azurerm_key_vault_access_policy" "api" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.api.principal_id

  secret_permissions = ["Get", "List"]
}

resource "azurerm_container_app" "api" {
  name                         = "${var.project}-${var.env}-api"
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.cae.id
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.api.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.api.id
  }

  ingress {
    external_enabled = var.containerapp_external_ingress
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "api"
      image  = var.container_image
      cpu    = 1.0
      memory = "2Gi"

      # Azure AI Search — endpoint only, auth via Managed Identity
      env {
        name  = "AZURE_SEARCH_ENDPOINT"
        value = "https://${azurerm_search_service.search.name}.search.windows.net"
      }

      # Azure OpenAI — endpoint only, auth via Managed Identity
      env {
        name  = "AZURE_OPENAI_ENDPOINT"
        value = azurerm_cognitive_account.openai.endpoint
      }

      # Managed Identity client ID — required for UserAssigned MI
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.api.client_id
      }

      # Postgres
      env {
        name  = "POSTGRES_HOST"
        value = azurerm_postgresql_flexible_server.pg.fqdn
      }

      env {
        name  = "POSTGRES_DB"
        value = azurerm_postgresql_flexible_server_database.agent.name
      }

      env {
        name  = "POSTGRES_USER"
        value = azurerm_postgresql_flexible_server.pg.administrator_login
      }

      # Redis
      env {
        name  = "REDIS_HOST"
        value = azurerm_redis_cache.redis.hostname
      }

      env {
        name  = "REDIS_SSL_PORT"
        value = tostring(azurerm_redis_cache.redis.ssl_port)
      }

      # Blob Storage
      env {
        name  = "BLOB_URI"
        value = "https://${azurerm_storage_account.sa.name}.blob.core.windows.net/${azurerm_storage_container.raw_docs.name}"
      }

      # Key Vault — only for Postgres password + Redis key (Search/OpenAI no longer need keys)
      env {
        name  = "KEYVAULT_URI"
        value = azurerm_key_vault.kv.vault_uri
      }

      env {
        name  = "KV_SECRET_PG_PASSWORD"
        value = azurerm_key_vault_secret.pg_password.name
      }

      env {
        name  = "KV_SECRET_REDIS_KEY"
        value = azurerm_key_vault_secret.redis_key.name
      }
     # Entra ID — tenant + audience for JWT validation
      env {
        name  = "ENTRA_TENANT_ID"
        value = data.azurerm_client_config.current.tenant_id
      }

      env {
        name  = "ENTRA_AUDIENCE"
        value = azuread_application.api.client_id
      }

      # App Insights
      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = azurerm_application_insights.ai.connection_string
      }
    }
  }

  depends_on = [
    azurerm_key_vault_access_policy.api,
    azurerm_role_assignment.api_acr_pull,
    azurerm_role_assignment.api_search_index_data_contributor,
    azurerm_role_assignment.api_openai_cognitive_services_user,
    azurerm_role_assignment.api_storage_blob_data_reader
  ]
}
