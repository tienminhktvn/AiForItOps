# Tương đương infra/core/acr.bicep

resource "azurerm_container_registry" "acr" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Basic"
  # true để bạn có thể `docker login` bằng admin user/password khi mới học,
  # thay vì phải setup service principal / az acr build ngay từ đầu.
  admin_enabled = true
  tags          = var.tags
}

# Cho phép AKS pull image từ ACR bằng managed identity (thay cho --attach-acr của az cli)
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = azurerm_container_registry.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = var.aks_identity_principal_id
  skip_service_principal_aad_check = true
}
