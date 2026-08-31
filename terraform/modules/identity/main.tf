resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "id-aks-keyvault"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "aks_identity_operator" {
  scope                = azurerm_user_assigned_identity.aks_identity.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

# Role assignment cần vài chục giây để lan truyền trong Azure AD trước khi AKS
# dùng được - nếu tạo cluster ngay sẽ vẫn bị lỗi dù role đã "tạo xong" ở API.
resource "time_sleep" "wait_for_identity_rbac" {
  depends_on      = [azurerm_role_assignment.aks_identity_operator]
  create_duration = "30s"
}
