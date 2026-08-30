# Tương đương infra/core/keyvault-secrets.bicep — lưu các connection string/key
# vào Key Vault để AKS đọc qua Secrets Store CSI Driver thay vì hard-code trong app.

resource "azurerm_key_vault_secret" "cosmosdb_connectionstring" {
  name         = "cosmosdb-connectionstring"
  value        = azurerm_cosmosdb_account.cosmos.primary_sql_connection_string
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_role_assignment.terraform_caller_kv_officer]
}

resource "azurerm_key_vault_secret" "servicebus_connectionstring" {
  name         = "servicebus-connectionstring"
  value        = azurerm_servicebus_namespace.sb.default_primary_connection_string
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_role_assignment.terraform_caller_kv_officer]
}

resource "azurerm_key_vault_secret" "openai_endpoint" {
  name         = "openai-endpoint"
  value        = azurerm_cognitive_account.openai.endpoint
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_role_assignment.terraform_caller_kv_officer]
}

resource "azurerm_key_vault_secret" "openai_key" {
  name         = "openai-key"
  value        = azurerm_cognitive_account.openai.primary_access_key
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_role_assignment.terraform_caller_kv_officer]
}

resource "azurerm_key_vault_secret" "openai_deployment" {
  name         = "openai-deployment"
  value        = azurerm_cognitive_deployment.openai_model.name
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_role_assignment.terraform_caller_kv_officer]
}
