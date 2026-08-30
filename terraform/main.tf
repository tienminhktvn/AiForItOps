resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Tạo chuỗi random để đảm bảo tính unique cho tên ACR/Key Vault/CosmosDB/ServiceBus/OpenAI
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}
