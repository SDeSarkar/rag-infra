resource "azurerm_redis_cache" "redis" {
  name                = "${var.project}-${var.env}-redis-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  family   = "C"
  sku_name = "Basic"
  capacity = 0

  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  tags = var.tags
}
