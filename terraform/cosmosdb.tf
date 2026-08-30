# Tương đương infra/core/cosmosdb.bicep

resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "${var.cosmosdb_account_name}-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  # Free tier: 1000 RU/s + 25GB miễn phí trọn đời, chỉ 1 account/subscription được bật.
  enable_free_tier = var.cosmosdb_free_tier_enabled

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
    zone_redundant    = false
  }

  tags = var.tags
}

resource "azurerm_cosmosdb_sql_database" "db" {
  name                = var.cosmosdb_database_name
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name

  # Throughput dùng chung cho cả 2 container bên dưới, giữ trong hạn mức free tier.
  throughput = var.cosmosdb_shared_throughput
}

resource "azurerm_cosmosdb_sql_container" "products" {
  name                = var.cosmosdb_products_container_name
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.db.name
  partition_key_path  = "/id"
}

resource "azurerm_cosmosdb_sql_container" "orders" {
  name                = var.cosmosdb_orders_container_name
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.db.name
  partition_key_path  = "/id"
}
