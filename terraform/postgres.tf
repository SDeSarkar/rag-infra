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

  version    = "16"
  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768

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


# ── Postgres Flexible Server ──────────────────────────────────────────────���───
resource "azurerm_postgresql_flexible_server" "pg" {
  name                   = "agentic-rag-dev-pg-${random_string.suffix.result}"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  version                = "16"
  administrator_login    = var.postgres_admin_user
  administrator_password = random_password.pg_admin.result
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"
  zone                   = "1"

  tags = local.tags
}

# ── Firewall — allow Container App Environment static IP ──────────────────────
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_container_app" {
  name             = "allow-container-app"
  server_id        = azurerm_postgresql_flexible_server.pg.id
  start_ip_address = azurerm_container_app_environment.cae.static_ip_address
  end_ip_address   = azurerm_container_app_environment.cae.static_ip_address
}

# ── Firewall — allow Azure services (optional but useful) ─────────────────────
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.pg.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
