data "azurerm_client_config" "current" {}

# Managed identity dùng chung cho AKS (kubelet identity) — tương đương infra/core/identity.bicep
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "id-aks-keyvault"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}
