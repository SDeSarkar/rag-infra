

# ACR pull
resource "azurerm_role_assignment" "api_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# Blob Storage — Container App MI read (unchanged)
resource "azurerm_role_assignment" "api_storage_blob_data_reader" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# Azure AI Search roles (unchanged)
resource "azurerm_role_assignment" "api_search_index_data_reader" {
  scope                = azurerm_search_service.search.id
  role_definition_name = "Search Index Data Reader"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

resource "azurerm_role_assignment" "api_search_index_data_contributor" {
  scope                = azurerm_search_service.search.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

resource "azurerm_role_assignment" "api_search_service_contributor" {
  scope                = azurerm_search_service.search.id
  role_definition_name = "Search Service Contributor"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# Azure OpenAI
resource "azurerm_role_assignment" "api_openai_cognitive_services_user" {
  scope                = azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# ── NEW: Deployer/CI identity — upload docs to Blob Storage ───────────────────
# Allows the SP or human identity running az cli / CI pipeline to upload
# documents to raw-docs without needing storage account keys.
resource "azurerm_role_assignment" "deployer_storage_blob_contributor" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id  # whoever runs terraform
}
