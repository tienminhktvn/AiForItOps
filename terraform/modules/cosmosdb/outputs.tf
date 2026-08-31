output "account_name" {
  value = azurerm_cosmosdb_account.cosmos.name
}

output "endpoint" {
  value = azurerm_cosmosdb_account.cosmos.endpoint
}

output "connection_string" {
  value     = azurerm_cosmosdb_account.cosmos.primary_sql_connection_string
  sensitive = true
}
