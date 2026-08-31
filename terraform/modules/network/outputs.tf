output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks_subnet.id
}

output "pe_subnet_id" {
  value = azurerm_subnet.pe_subnet.id
}

output "openai_dns_zone_id" {
  value = azurerm_private_dns_zone.openai_dns.id
}
