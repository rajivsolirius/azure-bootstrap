moved {
  from = azurerm_storage_account.app01_state
  to   = azurerm_storage_account.app_state["app01"]
}

moved {
  from = azapi_resource.app01_blob_service
  to   = azapi_resource.app_blob_service["app01"]
}

moved {
  from = azapi_resource.app01_state_container
  to   = azapi_resource.app_state_container["app01"]
}

moved {
  from = azurerm_private_endpoint.app01_state_blob
  to   = azurerm_private_endpoint.app_state_blob["app01"]
}

moved {
  from = azurerm_role_assignment.plan_state
  to   = azurerm_role_assignment.plan_state["app01"]
}

moved {
  from = azurerm_role_assignment.apply_state
  to   = azurerm_role_assignment.apply_state["app01"]
}

moved {
  from = azurerm_role_assignment.plan_reader
  to   = azurerm_role_assignment.plan_reader["app01"]
}

moved {
  from = azurerm_role_assignment.apply_contributor
  to   = azurerm_role_assignment.apply_contributor["app01"]
}

moved {
  from = azurerm_role_assignment.plan_resource_provider_registration
  to   = azurerm_role_assignment.plan_resource_provider_registration["app01"]
}

moved {
  from = azurerm_role_assignment.apply_app01_rbac_administrator
  to   = azurerm_role_assignment.apply_rbac_administrator["app01"]
}

moved {
  from = azurerm_role_definition.resource_provider_registration
  to   = azurerm_role_definition.resource_provider_registration["app01"]
}