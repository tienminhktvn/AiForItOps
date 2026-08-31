data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

module "network" {
  source = "./modules/network"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags
}

module "identity" {
  source = "./modules/identity"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags
}

module "acr" {
  source = "./modules/acr"

  name                      = "${var.acr_name}${random_string.suffix.result}"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  tags                      = var.tags
  aks_identity_principal_id = module.identity.principal_id
}

module "keyvault" {
  source = "./modules/keyvault"

  name                       = "${var.keyvault_name}-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  tags                       = var.tags
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  terraform_caller_object_id = data.azurerm_client_config.current.object_id
  principal_id               = var.principal_id
  aks_identity_principal_id  = module.identity.principal_id
}

module "cosmosdb" {
  source = "./modules/cosmosdb"

  account_name            = "${var.cosmosdb_account_name}-${random_string.suffix.result}"
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  tags                    = var.tags
  database_name           = var.cosmosdb_database_name
  products_container_name = var.cosmosdb_products_container_name
  orders_container_name   = var.cosmosdb_orders_container_name
  free_tier_enabled       = var.cosmosdb_free_tier_enabled
  shared_throughput       = var.cosmosdb_shared_throughput
}

module "servicebus" {
  source = "./modules/servicebus"

  namespace_name      = "${var.servicebus_namespace_name}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags
  sku                 = var.servicebus_sku
  queue_name          = var.servicebus_queue_name
}

module "openai" {
  source = "./modules/openai"

  resource_name       = "${var.openai_resource_name}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.openai_location
  tags                = var.tags
  deployment_name     = var.openai_deployment_name
  model_name          = var.openai_model_name
  model_version       = var.openai_model_version
  sku_capacity        = var.openai_sku_capacity
  pe_subnet_id        = module.network.pe_subnet_id
  private_dns_zone_id = module.network.openai_dns_zone_id
}

module "aks" {
  source = "./modules/aks"

  name                  = var.aks_name
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  tags                  = var.tags
  sku_tier              = var.aks_sku_tier
  node_count            = var.aks_node_count
  vm_size               = var.aks_vm_size
  subnet_id             = module.network.aks_subnet_id
  identity_id           = module.identity.id
  identity_client_id    = module.identity.client_id
  identity_principal_id = module.identity.principal_id
}

module "secrets" {
  source = "./modules/secrets"

  keyvault_id                  = module.keyvault.id_ready_for_secrets
  cosmosdb_connection_string   = module.cosmosdb.connection_string
  servicebus_connection_string = module.servicebus.connection_string
  openai_endpoint              = module.openai.endpoint
  openai_key                   = module.openai.primary_key
  openai_deployment_name       = module.openai.deployment_name
}
