resource "azurerm_resource_group" "rg" {
  name     = "${var.project}-${var.env}-rg"
  location = var.location
  tags     = var.tags
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  numeric = true
  special = false
}
