resource "azurerm_storage_account" "sa" {
  name                = replace("${var.project}${var.env}${random_string.suffix.result}", "-", "")
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # For MVP; consider disabling public network access later + private endpoints.
  public_network_access_enabled = true

  tags = var.tags
}

resource "azurerm_storage_container" "raw_docs" {
  name                  = "raw-docs"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "code_snapshots" {
  name                  = "code-snapshots"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "etl_artifacts" {
  name                  = "etl-artifacts"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}
