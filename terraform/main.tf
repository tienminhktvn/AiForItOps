resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Tạo chuỗi random để đảm bảo tính unique cho tên Key Vault và OpenAI
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}