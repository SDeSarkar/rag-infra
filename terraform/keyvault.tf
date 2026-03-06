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

  tenant_id = data.azurerm_client_config.current.tenant_id
  sku_name  = "standard"

  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  tags = var.tags
}

# ── Access policy: Terraform / CI-CD identity ─────────────────────────────────
resource "azurerm_key_vault_access_policy" "tf" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "Set", "List", "Delete", "Purge", "Recover"]
}

# ── Access policy: Container App Managed Identity ─────────────────────────────
#resource "azurerm_key_vault_access_policy" "api_mi" {
 # key_vault_id = azurerm_key_vault.kv.id
 # tenant_id    = data.azurerm_client_config.current.tenant_id
 # object_id    = azurerm_user_assigned_identity.api.principal_id

 # secret_permissions = ["Get", "List"]

  #lifecycle {
   # ignore_changes = all   # ← policy already exists in Azure, skip conflict
 # }
#}
