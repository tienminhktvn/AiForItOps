resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.name}-dns"
  sku_tier            = var.sku_tier

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

  kubelet_identity {
    client_id                 = var.identity_client_id
    object_id                 = var.identity_principal_id
    user_assigned_identity_id = var.identity_id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  node_provisioning_profile {
    mode = "Manual"
  }

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
