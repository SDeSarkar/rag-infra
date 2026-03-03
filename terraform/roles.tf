# ACR pull 
resource "azurerm_role_assignment" "api_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# Blob Storage — data plane read
resource "azurerm_role_assignment" "api_storage_blob_data_reader" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# Azure AI Search — data plane index + query operations via AAD
resource "azurerm_role_assignment" "api_search_index_data_contributor" {
  scope                = azurerm_search_service.search.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# Azure AI Search — read service metadata (optional but recommended)
resource "azurerm_role_assignment" "api_search_service_reader" {
  scope                = azurerm_search_service.search.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# Azure OpenAI — call models via AAD
resource "azurerm_role_assignment" "api_openai_cognitive_services_user" {
  scope                = azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}
