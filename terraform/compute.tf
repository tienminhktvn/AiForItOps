# Tương đương infra/core/aks.bicep
#
# Khác với bản Bicep gốc (2 node pool: system + user), bản Terraform này CHỈ dùng
# 1 node pool duy nhất để tiết kiệm quota vCPU trên subscription free-tier/Student.
# Nếu sau này có quota thoải mái hơn, có thể thêm azurerm_kubernetes_cluster_node_pool
# "user" pool riêng.

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${var.aks_name}-dns"
  sku_tier            = var.aks_sku_tier # "Free" -> không tính phí control plane

  default_node_pool {
    name           = "default"
    node_count     = var.aks_node_count
    vm_size        = var.aks_vm_size
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.aks_identity.id
    ]
  }

  # Dùng chính managed identity ở trên làm kubelet identity, để role assignment
  # (AcrPull, Key Vault Secrets User) đã cấp cho nó có hiệu lực trong cluster.
  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.aks_identity.client_id
    object_id                 = azurerm_user_assigned_identity.aks_identity.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.aks_identity.id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # OIDC + Workload Identity: nền tảng cho "zero static credential" (federated
  # identity credential cho từng ServiceAccount, xem Workshop/1-Identity.md)
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Azure CNI Overlay: pod lấy IP từ 1 dải ảo riêng (pod_cidr), KHÔNG tiêu tốn IP
  # của aks_subnet thật (chỉ node mới cần IP trong subnet) -> phù hợp subnet nhỏ /24
  # và né hẳn vấn đề trùng CIDR giữa VNet và Service CIDR.
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.245.0.0/16"
    dns_service_ip      = "10.245.0.10"
  }

  tags = var.tags
}
