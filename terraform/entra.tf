# ─�� App Registration for AgenticRAG API ──────────────────────────────────────
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
    description          = "Can ingest and query documents"
    display_name         = "RAGUser"
    enabled              = true
    id                   = "00000000-0000-0000-0000-000000000002"
    value                = "RAGUser"
  }

  tags = ["${var.project}", "${var.env}"]
}

# ── Service Principal ─────────────────────────────────────────────────────────
resource "azuread_service_principal" "api" {
  client_id                    = azuread_application.api.client_id
  app_role_assignment_required = false
}
