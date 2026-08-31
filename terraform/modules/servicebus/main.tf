resource "azurerm_servicebus_namespace" "sb" {
  name                = var.namespace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  tags                = var.tags
}

resource "azurerm_servicebus_queue" "queue" {
  name         = var.queue_name
  namespace_id = azurerm_servicebus_namespace.sb.id

  lock_duration                        = "PT5M"
  max_size_in_megabytes                = 1024
  requires_duplicate_detection         = false
  requires_session                     = false
  dead_lettering_on_message_expiration = false
  batched_operations_enabled           = true
  max_delivery_count                   = 10
}
