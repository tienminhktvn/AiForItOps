# Tương đương infra/core/keyvault.bicep

resource "azurerm_key_vault" "kv" {
  name                       = var.name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  tags                       = var.tags
}

# Cấp quyền đọc/ghi secret cho danh tính đang chạy `terraform apply` (user local
# hoặc service principal của pipeline) — bắt buộc phải có, nếu không module secrets
# sẽ apply lỗi 403.
resource "azurerm_role_assignment" "terraform_caller_kv_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.terraform_caller_object_id
}

# Tùy chọn: cấp thêm quyền cho 1 user cụ thể khác (vd. đồng đội) — bicep: secretsOfficerRoleAssignment
resource "azurerm_role_assignment" "user_kv_officer" {
  count                = var.principal_id != "" ? 1 : 0
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.principal_id
}

# Cấp quyền đọc secret cho AKS managed identity (CSI Secret Store Driver sẽ dùng identity này)
# bicep: secretsUserRoleAssignment
resource "azurerm_role_assignment" "aks_kv_reader" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.aks_identity_principal_id
}
