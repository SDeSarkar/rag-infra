data "azurerm_client_config" "current" {}

locals {
  # Key Vault names must be 3-24 chars, globally unique, and use a restricted charset.
  # This generates a short, lowercase, dashless name and truncates to 24 chars.
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

  # For Terraform to set secrets using access policies (MVP approach).
  # Alternative: RBAC-only Key Vault + role assignments.
  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  tags = var.tags
}

# Allow the current Terraform identity to manage secrets (MVP).
resource "azurerm_key_vault_access_policy" "tf" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "Set", "List", "Delete", "Purge", "Recover"]
}
