# ── App Registration ──────────────────────────────────────────────────────────
resource "azuread_application" "api" {
  display_name     = "${var.project}-${var.env}-api"
  identifier_uris  = ["api://agentic-rag"]
  sign_in_audience = "AzureADMyOrg"

  api {
    requested_access_token_version = 2
    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to access AgenticRAG API"
      admin_consent_display_name = "Access AgenticRAG API"
      enabled                    = true
      id                         = "00000000-0000-0000-0000-000000000001"
      type                       = "User"
      user_consent_description   = "Allow access to AgenticRAG API"
      user_consent_display_name  = "Access AgenticRAG API"
      value                      = "access_as_user"
    }
  }

  app_role {
    allowed_member_types = ["User", "Application"]
    description          = "Deprecated — replaced by sre role"
    display_name         = "RAGUser (deprecated)"
    enabled              = false
    id                   = "00000000-0000-0000-0000-000000000002"
    value                = "RAGUser"
  }

  app_role {
    allowed_member_types = ["User", "Application"]
    description          = "SRE team — can ingest and query documents"
    display_name         = "SRE"
    enabled              = true
    id                   = "11111111-1111-1111-1111-111111111111"
    value                = "sre"
  }

  app_role {
    allowed_member_types = ["User", "Application"]
    description          = "Engineer — can ingest and query documents"
    display_name         = "Engineer"
    enabled              = true
    id                   = "22222222-2222-2222-2222-222222222222"
    value                = "engineer"
  }

  tags = ["${var.project}", "${var.env}"]
}

# ── Service Principal ─────────────────────────────────────────────────────────
resource "azuread_service_principal" "api" {
  client_id                    = azuread_application.api.client_id
  app_role_assignment_required = false
}

# ── Client Secret for scripts / CI to get tokens ─────────────────────────────
# Stored in Key Vault — never in Terraform state plaintext
resource "azuread_application_password" "api_secret" {
  application_id = azuread_application.api.id
  display_name   = "terraform-managed"
  end_date       = "2099-01-01T00:00:00Z"   # rotate via terraform taint if needed
}

# Store secret in Key Vault so scripts/CI fetch it securely
resource "azurerm_key_vault_secret" "api_client_secret" {
  name         = "EntraApp-ClientSecret"
  value        = azuread_application_password.api_secret.value
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_key_vault_access_policy.tf]
}

# ── Assign sre role to Managed Identity ──────────────────────────────────────
resource "azuread_app_role_assignment" "api_mi_sre" {
  app_role_id         = "11111111-1111-1111-1111-111111111111"
  principal_object_id = azurerm_user_assigned_identity.api.principal_id
  resource_object_id  = azuread_service_principal.api.object_id

  depends_on = [
    azurerm_user_assigned_identity.api,
    azuread_service_principal.api,
  ]
}

# ── Assign sre role to additional SPs (CI pipeline etc.) ─────────────────────
resource "azuread_app_role_assignment" "raguser_assignments" {
  for_each            = toset(var.raguser_client_ids)
  app_role_id         = "11111111-1111-1111-1111-111111111111"
  principal_object_id = data.azuread_service_principal.raguser_principals[each.value].object_id
  resource_object_id  = azuread_service_principal.api.object_id
}

data "azuread_service_principal" "raguser_principals" {
  for_each  = toset(var.raguser_client_ids)
  client_id = each.value
}
