locals {
  bootstrap_state_container_scope = join("", [
    "/subscriptions/",
    var.management_subscription_id,
    "/resourceGroups/",
    var.bootstrap_backend_resource_group_name,
    "/providers/Microsoft.Storage/storageAccounts/",
    var.bootstrap_backend_storage_account_name,
    "/blobServices/default/containers/tfstate"
  ])
}

#
# ----------------------------------------------------------
# App Backend Terraform state access
# ----------------------------------------------------------
#

resource "azurerm_role_assignment" "plan_bootstrap_state" {
  scope                = local.bootstrap_state_container_scope
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.plan.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "apply_bootstrap_state" {
  scope                = local.bootstrap_state_container_scope
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.apply.principal_id
  principal_type       = "ServicePrincipal"
}

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
# Management subscription permissions
# ----------------------------------------------------------
#

resource "azurerm_role_assignment" "plan_management_reader" {
  scope = "/subscriptions/${var.management_subscription_id}"

  role_definition_name = "Reader"

  principal_id = azurerm_user_assigned_identity.plan.principal_id

  principal_type = "ServicePrincipal"
}

resource "azurerm_role_assignment" "apply_management_reader" {
  scope = "/subscriptions/${var.management_subscription_id}"

  role_definition_name = "Reader"

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

#
# ----------------------------------------------------------
# Custom role allowing Resource Provider registration only
# ----------------------------------------------------------
#

resource "azurerm_role_definition" "resource_provider_registration" {
  name        = "Application Resource Provider Registration Operator"
  scope       = "/subscriptions/${var.app01_subscription_id}"
  description = "Allows registration and reading of Azure Resource Providers in the App01 subscription."

  permissions {
    actions = [
      "Microsoft.Resources/subscriptions/providers/read",
      "Microsoft.Resources/subscriptions/providers/register/action"
    ]

    not_actions = []
  }

  assignable_scopes = [
    "/subscriptions/${var.app01_subscription_id}"
  ]
}


#
# ----------------------------------------------------------
# Assign custom RP-registration role to Plan identity Only
# ----------------------------------------------------------
#

resource "azurerm_role_assignment" "plan_resource_provider_registration" {
  scope = "/subscriptions/${var.app01_subscription_id}"

  role_definition_id = azurerm_role_definition.resource_provider_registration.role_definition_resource_id

  principal_id = azurerm_user_assigned_identity.plan.principal_id

  principal_type = "ServicePrincipal"
}