resource "random_password" "pg_admin" {
  length  = 22
  special = true
}

resource "azurerm_postgresql_flexible_server" "pg" {
  name                = "${var.project}-${var.env}-pg-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  administrator_login    = "pgadminuser"
  administrator_password = random_password.pg_admin.result

  version      = "16"
  sku_name     = "B_Standard_B1ms"
  storage_mb   = 32768

  # MVP: public. Production: private access only.
  public_network_access_enabled = true

  tags = var.tags
}

resource "azurerm_postgresql_flexible_server_database" "agent" {
  name      = "agent"
  server_id = azurerm_postgresql_flexible_server.pg.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}
