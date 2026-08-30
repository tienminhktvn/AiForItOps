output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "aks_identity_client_id" {
  value = azurerm_user_assigned_identity.aks_identity.client_id
}

output "aks_oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "cosmosdb_account_name" {
  value = azurerm_cosmosdb_account.cosmos.name
}

output "cosmosdb_endpoint" {
  value = azurerm_cosmosdb_account.cosmos.endpoint
}

output "servicebus_namespace" {
  value = azurerm_servicebus_namespace.sb.name
}

output "keyvault_name" {
  value = azurerm_key_vault.kv.name
}

output "keyvault_uri" {
  value = azurerm_key_vault.kv.vault_uri
}

output "openai_name" {
  value = azurerm_cognitive_account.openai.name
}

output "openai_endpoint" {
  value = azurerm_cognitive_account.openai.endpoint
}

output "openai_deployment_name" {
  value = azurerm_cognitive_deployment.openai_model.name
}
