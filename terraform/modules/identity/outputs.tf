# Cả 3 output đều depends_on time_sleep: bất kỳ module nào dùng output của module
# này (acr, keyvault, aks) sẽ tự động phải đợi role "Managed Identity Operator"
# lan truyền xong trước, không cần tự khai báo depends_on lại ở module gọi.

output "id" {
  value      = azurerm_user_assigned_identity.aks_identity.id
  depends_on = [time_sleep.wait_for_identity_rbac]
}

output "principal_id" {
  value      = azurerm_user_assigned_identity.aks_identity.principal_id
  depends_on = [time_sleep.wait_for_identity_rbac]
}

output "client_id" {
  value      = azurerm_user_assigned_identity.aks_identity.client_id
  depends_on = [time_sleep.wait_for_identity_rbac]
}
