resource "azurerm_private_endpoint" "app_state_blob" {
  for_each = var.application_landing_zones

  name                = "pe-${azurerm_storage_account.app_state[each.key].name}-blob"
  location            = azurerm_resource_group.state.location
  resource_group_name = azurerm_resource_group.state.name

  subnet_id = var.private_endpoint_subnet_id

  private_service_connection {
    name = "psc-${azurerm_storage_account.app_state[each.key].name}-blob"

    private_connection_resource_id = azurerm_storage_account.app_state[each.key].id

    subresource_names = [
      "blob"
    ]

    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "default"

    private_dns_zone_ids = [
      var.private_dns_zone_id
    ]
  }
}