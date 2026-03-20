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
resource "azurerm_key_vault_access_policy" "tf" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "Set", "List", "Delete", "Purge", "Recover"]
}

# ── Access policy: Human admins ───────────────────────────────────────────────
resource "azurerm_key_vault_access_policy" "admins" {
  for_each = toset(var.admin_object_ids)

  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = each.value

  secret_permissions = ["Get", "Set", "List", "Delete", "Purge", "Recover"]
  key_permissions    = ["Get", "List"]
}

# ── Access policy: Container App Managed Identity ─────────────────────────────
resource "azurerm_key_vault_access_policy" "api_mi" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.api.principal_id

  secret_permissions = ["Get", "List"]

  depends_on = [azurerm_key_vault_access_policy.tf]

  # ── Prevent "already exists" errors on partial redeploys ─────────────────
  # If the policy exists in Azure but not in state, import step handles it.
  # If it exists in both, this is a no-op.
  lifecycle {
    ignore_changes = [object_id]
  }
}
