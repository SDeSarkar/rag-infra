resource "azurerm_container_registry" "acr" {
  name                = replace("${var.project}${var.env}${random_string.suffix.result}", "-", "")
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku           = "Basic"
  admin_enabled = false # MVP. Production: prefer Managed Identity + AcrPull.

  tags = var.tags
}
