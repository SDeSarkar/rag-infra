# ── App Registration for AgenticRAG API ──────────────────────────────────────
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
    description          = "SRE team — can ingest and query documents"
    display_name         = "SRE"
    enabled              = true
    id                   = "00000000-0000-0000-0000-000000000002"
    value                = "sre"   # ← matches require_role("sre", "engineer")
  }

  app_role {
    allowed_member_types = ["User", "Application"]
    description          = "Engineer — can ingest and query documents"
    display_name         = "Engineer"
    enabled              = true
    id                   = "00000000-0000-0000-0000-000000000003"
    value                = "engineer"   # ← matches require_role("sre", "engineer")
  }

  tags = ["${var.project}", "${var.env}"]
}

# ── Service Principal ─────────────────────────────────────────────────────────
resource "azuread_service_principal" "api" {
  client_id                    = azuread_application.api.client_id
  app_role_assignment_required = false
}

# ── Service Principal for the Managed Identity ────────────────────────────────
data "azuread_service_principal" "api_mi" {
  client_id = azurerm_user_assigned_identity.api.client_id
}

# ── Assign sre role to Managed Identity and test client SP ───────────────────
resource "azuread_app_role_assignment" "api_mi_sre" {
  app_role_id         = "00000000-0000-0000-0000-000000000002"  # sre
  principal_object_id = data.azuread_service_principal.api_mi.object_id
  resource_object_id  = azuread_service_principal.api.object_id
}

resource "azuread_app_role_assignment" "raguser_assignments" {
  for_each            = toset(var.raguser_client_ids)
  app_role_id         = "00000000-0000-0000-0000-000000000002"  # sre
  principal_object_id = data.azuread_service_principal.raguser_principals[each.value].object_id
  resource_object_id  = azuread_service_principal.api.object_id
}

data "azuread_service_principal" "raguser_principals" {
  for_each  = toset(var.raguser_client_ids)
  client_id = each.value
}
