#
# ----------------------------------------------------------
# App01 Terraform state access
# ----------------------------------------------------------
#

resource "azurerm_role_assignment" "plan_state" {
  scope = azapi_resource.app01_state_container.id

  role_definition_name = "Storage Blob Data Contributor"

  principal_id = azurerm_user_assigned_identity.plan.principal_id

  principal_type = "ServicePrincipal"
}

resource "azurerm_role_assignment" "apply_state" {
  scope = azapi_resource.app01_state_container.id

  role_definition_name = "Storage Blob Data Contributor"

  principal_id = azurerm_user_assigned_identity.apply.principal_id

  principal_type = "ServicePrincipal"
}


#
# ----------------------------------------------------------
# Application subscription permissions
# ----------------------------------------------------------
#

resource "azurerm_role_assignment" "plan_reader" {
  scope = "/subscriptions/${var.app01_subscription_id}"

  role_definition_name = "Reader"

  principal_id = azurerm_user_assigned_identity.plan.principal_id

  principal_type = "ServicePrincipal"
}

resource "azurerm_role_assignment" "apply_contributor" {
  scope = "/subscriptions/${var.app01_subscription_id}"

  role_definition_name = "Contributor"

  principal_id = azurerm_user_assigned_identity.apply.principal_id

  principal_type = "ServicePrincipal"
}