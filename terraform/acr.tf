# Tương đương infra/core/acr.bicep

resource "azurerm_container_registry" "acr" {
  name                = "${var.acr_name}${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
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
  principal_id                     = azurerm_user_assigned_identity.aks_identity.principal_id
  skip_service_principal_aad_check = true
}
