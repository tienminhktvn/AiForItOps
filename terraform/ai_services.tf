# Tương đương infra/core/openai.bicep
#
# custom_subdomain_name là bắt buộc để dùng được Private Endpoint (nếu không set,
# Azure không tạo DNS record riêng cho resource -> private_endpoint bên dưới sẽ lỗi).

resource "azurerm_cognitive_account" "openai" {
  name                          = "${var.openai_resource_name}-${random_string.suffix.result}"
  location                      = var.openai_location
  resource_group_name           = azurerm_resource_group.rg.name
  kind                          = "OpenAI"
  sku_name                      = "S0"
  custom_subdomain_name         = "${var.openai_resource_name}-${random_string.suffix.result}"
  public_network_access_enabled = false
  tags                          = var.tags
}

resource "azurerm_cognitive_deployment" "openai_model" {
  name                 = var.openai_deployment_name
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = var.openai_model_name
    version = var.openai_model_version
  }

  # GlobalStandard rẻ hơn Standard và vẫn nằm trong quota mặc định của subscription
  # free-tier/student. capacity tính theo nghìn TPM (tokens-per-minute).
  scale {
    type     = "GlobalStandard"
    capacity = var.openai_sku_capacity
  }
}

resource "azurerm_private_endpoint" "openai_pe" {
  name                = "pe-openai"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.pe_subnet.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-openai"
    private_connection_resource_id = azurerm_cognitive_account.openai.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.openai_dns.id]
  }
}
