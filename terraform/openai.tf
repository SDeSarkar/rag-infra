resource "azurerm_cognitive_account" "openai" {
  name                = "${var.project}-${var.env}-openai-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  kind     = "OpenAI"
  sku_name = "S0"

  # For MVP; later: private endpoints and restrict network.
  public_network_access_enabled = true

  tags = var.tags
}
