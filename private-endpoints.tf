resource "azurerm_private_endpoint" "app01_state_blob" {
  name                = "pe-${azurerm_storage_account.app01_state.name}-blob"
  location            = azurerm_resource_group.state.location
  resource_group_name = azurerm_resource_group.state.name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name = "psc-${azurerm_storage_account.app01_state.name}-blob"

    private_connection_resource_id = azurerm_storage_account.app01_state.id

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