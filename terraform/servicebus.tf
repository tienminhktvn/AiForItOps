# Tương đương infra/core/servicebus.bicep

resource "azurerm_servicebus_namespace" "sb" {
  name                = "${var.servicebus_namespace_name}-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = var.servicebus_sku
  tags                = var.tags
}

resource "azurerm_servicebus_queue" "queue" {
  name         = var.servicebus_queue_name
  namespace_id = azurerm_servicebus_namespace.sb.id

  lock_duration                        = "PT5M"
  max_size_in_megabytes                = 1024
  requires_duplicate_detection         = false
  requires_session                     = false
  dead_lettering_on_message_expiration = false
  enable_batched_operations            = true
  max_delivery_count                   = 10
}
