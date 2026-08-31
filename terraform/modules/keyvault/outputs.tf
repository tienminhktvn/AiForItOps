output "id" {
  value = azurerm_key_vault.kv.id
}

output "name" {
  value = azurerm_key_vault.kv.name
}

output "vault_uri" {
  value = azurerm_key_vault.kv.vault_uri
}

# Dùng output này (thay vì "id" ở trên) ở bất kỳ đâu cần GHI secret vào Key Vault
# (module secrets) — nó ép buộc phải đợi role Key Vault Secrets Officer của người
# gọi terraform lan truyền xong, nếu không apply sẽ lỗi 403 Forbidden.
output "id_ready_for_secrets" {
  value      = azurerm_key_vault.kv.id
  depends_on = [azurerm_role_assignment.terraform_caller_kv_officer]
}
