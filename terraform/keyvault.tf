data "azurerm_client_config" "current" {}

locals {
  kv_name = substr(
    lower(replace("${var.project}${var.env}kv${random_string.suffix.result}", "-", "")),
    0,
    24
  )
}

resource "azurerm_key_vault" "kv" {
  name                = local.kv_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  tags = var.tags
}

# ── Access policy: GitHub Actions OIDC SP ────────────────────────────────────
# Full access — writes secrets during apply, reads them during ingest workflow
resource "azurerm_key_vault_access_policy" "tf" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "Set", "List", "Delete", "Purge", "Recover"]
}

# ── Access policy: Container App Managed Identity ─────────────────────────────
# App reads secrets at runtime (pg password, redis key, openai key)
resource "azurerm_key_vault_access_policy" "api_mi" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.api.principal_id

  secret_permissions = ["Get", "List"]

  depends_on = [azurerm_key_vault_access_policy.tf]
}

# ── Access policy: Human admins (YOUR personal OID) ───────────────────────────
# NOT managed by Terraform — created once manually, never destroyed
# See: scripts/setup_kv_admin_access.sh
#
# az keyvault set-policy \
#   --name <kv-name> \
#   --object-id <your-oid> \
#   --secret-permissions get list set delete
#
# This is intentionally outside Terraform lifecycle so terraform destroy
# does not remove your portal/CLI access to the Key Vault.
