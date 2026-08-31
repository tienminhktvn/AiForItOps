resource "azurerm_key_vault_secret" "cosmosdb_connectionstring" {
  name         = "cosmosdb-connectionstring"
  value        = var.cosmosdb_connection_string
  key_vault_id = var.keyvault_id
}

resource "azurerm_key_vault_secret" "servicebus_connectionstring" {
  name         = "servicebus-connectionstring"
  value        = var.servicebus_connection_string
  key_vault_id = var.keyvault_id
}

resource "azurerm_key_vault_secret" "openai_endpoint" {
  name         = "openai-endpoint"
  value        = var.openai_endpoint
  key_vault_id = var.keyvault_id
}

resource "azurerm_key_vault_secret" "openai_key" {
  name         = "openai-key"
  value        = var.openai_key
  key_vault_id = var.keyvault_id
}

resource "azurerm_key_vault_secret" "openai_deployment" {
  name         = "openai-deployment"
  value        = var.openai_deployment_name
  key_vault_id = var.keyvault_id
}
