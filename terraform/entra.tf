# ── App Registration for AgenticRAG API ───────────────────────────────────────
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

  # ── DEPRECATED: old RAGUser role — disabled before removal (Azure requirement)
  app_role {
    allowed_member_types = ["User", "Application"]
    description          = "Deprecated — replaced by sre role"
    display_name         = "RAGUser (deprecated)"
    enabled              = false
    id                   = "00000000-0000-0000-0000-000000000002"
    value                = "RAGUser"
  }

  # ── sre role ─────────────────────────────────────────────────────────────────
  app_role {
    allowed_member_types = ["User", "Application"]
    description          = "SRE team — can ingest and query documents"
    display_name         = "SRE"
    enabled              = true
    id                   = "11111111-1111-1111-1111-111111111111"
    value                = "sre"
  }

  # ── engineer role ─────────────────────────────────────────────────────────────
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

# ── Service Principal for the App Registration ────────────────────────────────
resource "azuread_service_principal" "api" {
  client_id                    = azuread_application.api.client_id
  app_role_assignment_required = false
}

# ── Assign sre role to the Managed Identity ───────────────────────────────────
# FIX: Use azurerm_user_assigned_identity.api.principal_id directly.
# The old approach used a data "azuread_service_principal" lookup by client_id,
# which fails on fresh deployments because Azure AD replication of the MI's SP
# can take 5–30 minutes. The principal_id attribute is available immediately
# from the azurerm resource without any Entra ID graph query.
resource "azuread_app_role_assignment" "api_mi_sre" {
  app_role_id         = "11111111-1111-1111-1111-111111111111"  # sre role
  principal_object_id = azurerm_user_assigned_identity.api.principal_id  # ← direct, no data lookup
  resource_object_id  = azuread_service_principal.api.object_id

  depends_on = [
    azurerm_user_assigned_identity.api,
    azuread_service_principal.api,
  ]
}

# ── Assign sre role to test client SPs (e.g. CI pipeline, manual testing) ─────
resource "azuread_app_role_assignment" "raguser_assignments" {
  for_each            = toset(var.raguser_client_ids)
  app_role_id         = "11111111-1111-1111-1111-111111111111"  # sre role
  principal_object_id = data.azuread_service_principal.raguser_principals[each.value].object_id
  resource_object_id  = azuread_service_principal.api.object_id
}

data "azuread_service_principal" "raguser_principals" {
  for_each  = toset(var.raguser_client_ids)
  client_id = each.value
}
