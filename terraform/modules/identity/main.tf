# Managed identity dùng chung cho AKS (cluster identity + kubelet identity)
# — tương đương infra/core/identity.bicep

resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "id-aks-keyvault"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Dùng CHUNG 1 identity vừa làm cluster identity vừa làm kubelet identity (module aks)
# nên identity này phải được cấp quyền "Managed Identity Operator" lên chính nó -
# nếu không AKS sẽ báo lỗi CustomKubeletIdentityMissingPermissionError khi tạo cluster.
# https://learn.microsoft.com/azure/aks/use-managed-identity#add-role-assignment
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
