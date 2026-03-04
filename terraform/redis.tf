resource "azurerm_redis_cache" "redis" {
  name                = "${var.project}-${var.env}-redis-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  family   = "C"
  sku_name = "Basic"
  capacity = 0

  minimum_tls_version = "1.2"

  tags = var.tags
}

# ── Firewall — allow Container App Environment static IP ──────────────────────
resource "azurerm_redis_firewall_rule" "allow_container_app" {
  name                = "allow_container_app"
  redis_cache_name    = azurerm_redis_cache.redis.name
  resource_group_name = azurerm_resource_group.rg.name
  start_ip            = azurerm_container_app_environment.cae.static_ip_address
  end_ip              = azurerm_container_app_environment.cae.static_ip_address
}
