resource "azurerm_search_service" "search" {
  name                = "${var.project}-${var.env}-search-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku             = "basic"
  replica_count   = 1
  partition_count = 1

  tags = var.tags
}
