output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

# Storage
output "storage_account_name" {
  value = azurerm_storage_account.sa.name
}

output "storage_raw_docs_container" {
  value = azurerm_storage_container.raw_docs.name
}

# Search
output "search_service_name" {
  value = azurerm_search_service.search.name
}

output "search_endpoint" {
  value = "https://${azurerm_search_service.search.name}.search.windows.net"
}

# Azure OpenAI
output "aoai_endpoint" {
  value = azurerm_cognitive_account.openai.endpoint
}

# ACR
output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  value     = azurerm_container_registry.acr.admin_username
  sensitive = true
}

output "acr_admin_password" {
  value     = azurerm_container_registry.acr.admin_password
  sensitive = true
}

# App Insights
output "app_insights_connection_string" {
  value     = azurerm_application_insights.ai.connection_string
  sensitive = true
}

# Container Apps
output "aca_environment_id" {
  value = azurerm_container_app_environment.cae.id
}

output "container_app_fqdn" {
  value = try(azurerm_container_app.api.ingress[0].fqdn, null)
}

# Data services
output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.pg.fqdn
}

output "redis_hostname" {
  value = azurerm_redis_cache.redis.hostname
}

output "container_app_environment_static_ip" {
  description = "Static outbound IP of the Container App Environment (used in firewall rules)"
  value       = azurerm_container_app_environment.cae.static_ip_address
}

output "container_app_fqdn" {
  description = "FQDN of the Container App"
  value       = azurerm_container_app.api.latest_revision_fqdn
}

output "acr_login_server" {
  description = "ACR login server"
  value       = azurerm_container_registry.acr.login_server
}

output "postgres_host" {
  description = "Postgres server FQDN"
  value       = azurerm_postgresql_flexible_server.pg.fqdn
  sensitive   = false
}
