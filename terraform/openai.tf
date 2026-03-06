resource "azurerm_cognitive_account" "openai" {
  name                = "${var.project}-${var.env}-openai-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  kind     = "OpenAI"
  sku_name = "S0"
  # REQUIRED FOR MANAGED IDENTITY
  custom_subdomain_name = "rag-agent-api-${var.environment}" 
  public_network_access_enabled = true

  tags = var.tags
}



# ── Model Deployments ─────────────────────────────────────────────────────────
resource "azurerm_cognitive_deployment" "gpt4o" {
  name                 = var.openai_chat_deployment
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-11-20"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 10
  }
}

resource "azurerm_cognitive_deployment" "text_embedding" {
  name                 = var.openai_embedding_deployment
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "text-embedding-3-large"
    version = "1"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 10
  }

  depends_on = [azurerm_cognitive_deployment.gpt4o]
}
