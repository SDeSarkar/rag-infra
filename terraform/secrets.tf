resource "azurerm_key_vault_secret" "search_admin_key" {
  name         = "AzureAISearch-AdminKey"
  value        = azurerm_search_service.search.primary_key
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault_access_policy.tf]
}

resource "azurerm_key_vault_secret" "openai_endpoint" {
  name         = "AzureOpenAI-Endpoint"
  value        = azurerm_cognitive_account.openai.endpoint
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault_access_policy.tf]
}

# Store OpenAI API key in Key Vault — used for regional endpoints (e.g. South India)
# that do not support Managed Identity auth for Azure OpenAI
resource "azurerm_key_vault_secret" "openai_api_key" {
  name         = "AzureOpenAI-ApiKey"
  value        = azurerm_cognitive_account.openai.primary_access_key
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault_access_policy.tf]
}

resource "azurerm_key_vault_secret" "pg_password" {
  name         = "Postgres-AdminPassword"
  value        = random_password.pg_admin.result
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault_access_policy.tf]
}

resource "azurerm_key_vault_secret" "redis_key" {
  name         = "Redis-PrimaryKey"
  value        = azurerm_redis_cache.redis.primary_access_key
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault_access_policy.tf]
}
