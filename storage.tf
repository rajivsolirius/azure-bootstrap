resource "azurerm_resource_group" "state" {
  name     = "${var.resource_group_name}-state"
  location = var.location
}


#resource "azurerm_storage_account" "app01_state" {
#  name                = var.app01_state_storage_account_name
#  resource_group_name = azurerm_resource_group.state.name
#  location            = azurerm_resource_group.state.location
#
#  account_tier             = "Standard"
#  account_replication_type = "LRS"
#
#  min_tls_version                  = "TLS1_2"
#  public_network_access_enabled    = false
#  allow_nested_items_to_be_public = false
#  shared_access_key_enabled        = false
#}

resource "azurerm_storage_account" "app_state" {
  for_each = var.application_landing_zones

  name                = each.value.state_storage_account_name
  resource_group_name = azurerm_resource_group.state.name
  location            = azurerm_resource_group.state.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                  = "TLS1_2"
  public_network_access_enabled    = false
  allow_nested_items_to_be_public = false
  shared_access_key_enabled        = false
}

#
# Create the Blob service via ARM.
#
#resource "azapi_resource" "app01_blob_service" {
#  type      = "Microsoft.Storage/storageAccounts/blobServices@2023-05-01"
#  name      = "default"
#  parent_id = azurerm_storage_account.app01_state.id
#
#  body = {}
#}

resource "azapi_resource" "app_blob_service" {
  for_each = var.application_landing_zones

  type      = "Microsoft.Storage/storageAccounts/blobServices@2023-05-01"
  name      = "default"
  parent_id = azurerm_storage_account.app_state[each.key].id

  body = {}
}

#
# Create the tfstate container through ARM.
#
# This avoids needing data-plane connectivity simply to create
# the container on a private Storage Account.
#
#resource "azapi_resource" "app01_state_container" {
#  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01"
#  name      = "tfstate"
#  parent_id = azapi_resource.app01_blob_service.id
#
#  body = {
#    properties = {
#      publicAccess = "None"
#    }
#  }
#}

resource "azapi_resource" "app_state_container" {
  for_each = var.application_landing_zones

  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01"
  name      = "tfstate"
  parent_id = azapi_resource.app_blob_service[each.key].id

  body = {
    properties = {
      publicAccess = "None"
    }
  }
}