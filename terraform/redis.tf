resource "azurerm_redis_cache" "redis" {
  name                = "${var.project}-${var.env}-redis-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  family   = "C"
  sku_name = "Basic"
  capacity = 0

  minimum_tls_version = "1.2"

  # OPTIONAL: redis_configuration block if you need it (leave empty otherwise)
  # redis_configuration {
  # }

  tags = var.tags
}

# ── Redis firewall — allow Container App Environment ──────────────────────────
# Note: Azure Cache for Redis uses firewall rules differently
resource "azurerm_redis_firewall_rule" "allow_container_app" {
  name                = "allow-container-app"
  redis_cache_name    = azurerm_redis_cache.redis.name
  resource_group_name = azurerm_resource_group.rg.name
  start_ip            = azurerm_container_app_environment.cae.static_ip_address
  end_ip              = azurerm_container_app_environment.cae.static_ip_address
}
