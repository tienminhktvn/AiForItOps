# Tương đương infra/core/openai.bicep
#
# custom_subdomain_name là bắt buộc để dùng được Private Endpoint (nếu không set,
# Azure không tạo DNS record riêng cho resource -> private_endpoint bên dưới sẽ lỗi).

resource "azurerm_cognitive_account" "openai" {
  name                          = var.resource_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  kind                          = "OpenAI"
  sku_name                      = "S0"
  custom_subdomain_name         = var.resource_name
  public_network_access_enabled = false
  tags                          = var.tags
}

resource "azurerm_cognitive_deployment" "openai_model" {
  name                 = var.deployment_name
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = var.model_name
    version = var.model_version
  }

  # GlobalStandard rẻ hơn Standard và vẫn nằm trong quota mặc định của subscription
  # free-tier/student. capacity tính theo nghìn TPM (tokens-per-minute).
  sku {
    name     = "GlobalStandard"
    capacity = var.sku_capacity
  }
}

# Cognitive Services account báo "Succeeded" ở tầng ARM sớm hơn lúc nội bộ dịch vụ
# thực sự sẵn sàng cho Private Link (vẫn ở state "Accepted" thêm một lúc) - phải đợi
# thêm trước khi tạo Private Endpoint, nếu không sẽ lỗi AccountProvisioningStateInvalid.
resource "time_sleep" "wait_for_openai" {
  depends_on      = [azurerm_cognitive_account.openai, azurerm_cognitive_deployment.openai_model]
  create_duration = "60s"
}

resource "azurerm_private_endpoint" "openai_pe" {
  depends_on = [time_sleep.wait_for_openai]

  name                = "pe-openai"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-openai"
    private_connection_resource_id = azurerm_cognitive_account.openai.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}
