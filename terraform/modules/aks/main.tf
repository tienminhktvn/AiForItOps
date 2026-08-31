# Tương đương infra/core/aks.bicep
#
# Khác với bản Bicep gốc (2 node pool: system + user), bản Terraform này CHỈ dùng
# 1 node pool duy nhất để tiết kiệm quota vCPU trên subscription free-tier/Student.
# Nếu sau này có quota thoải mái hơn, có thể thêm azurerm_kubernetes_cluster_node_pool
# "user" pool riêng.
#
# Việc chờ role "Managed Identity Operator" lan truyền xong (time_sleep) đã được xử lý
# bên trong module identity - 3 input var identity_id/identity_client_id/identity_principal_id
# đều đến từ output có depends_on time_sleep đó, nên module này không cần tự chờ lại.

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.name}-dns"
  sku_tier            = var.sku_tier # "Free" -> không tính phí control plane

  default_node_pool {
    name           = "default"
    node_count     = var.node_count
    vm_size        = var.vm_size
    vnet_subnet_id = var.subnet_id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  # Dùng chính managed identity ở trên làm kubelet identity, để role assignment
  # (AcrPull, Key Vault Secrets User) đã cấp cho nó có hiệu lực trong cluster.
  kubelet_identity {
    client_id                 = var.identity_client_id
    object_id                 = var.identity_principal_id
    user_assigned_identity_id = var.identity_id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # Bắt buộc từ azurerm provider v5: "Manual" = node pool quản lý thủ công như
  # cluster này đang làm (khác với "Auto" = Node Autoprovisioning/Karpenter).
  node_provisioning_profile {
    mode = "Manual"
  }

  # OIDC + Workload Identity: nền tảng cho "zero static credential" (federated
  # identity credential cho từng ServiceAccount, xem Workshop/1-Identity.md)
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Azure CNI Overlay: pod lấy IP từ 1 dải ảo riêng (pod_cidr), KHÔNG tiêu tốn IP
  # của subnet thật (chỉ node mới cần IP trong subnet) -> phù hợp subnet nhỏ /24
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
