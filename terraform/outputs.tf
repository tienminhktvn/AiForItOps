output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "acr_name" {
  value = module.acr.name
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "aks_name" {
  value = module.aks.name
}

output "aks_identity_client_id" {
  value = module.identity.client_id
}

output "aks_oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "cosmosdb_account_name" {
  value = module.cosmosdb.account_name
}

output "cosmosdb_endpoint" {
  value = module.cosmosdb.endpoint
}

output "servicebus_namespace" {
  value = module.servicebus.namespace_name
}

output "keyvault_name" {
  value = module.keyvault.name
}

output "keyvault_uri" {
  value = module.keyvault.vault_uri
}

output "openai_name" {
  value = module.openai.name
}

output "openai_endpoint" {
  value = module.openai.endpoint
}

output "openai_deployment_name" {
  value = module.openai.deployment_name
}
