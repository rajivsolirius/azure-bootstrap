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

  connectivity_subscription_scope = "/subscriptions/${var.connectivity_subscription_id}"

  hub_resource_group_scope = join("", [
    "/subscriptions/",
    var.connectivity_subscription_id,
    "/resourceGroups/",
    var.hub_virtual_network_resource_group_name
  ])

  hub_virtual_network_scope = join("", [
    local.hub_resource_group_scope,
    "/providers/Microsoft.Network/virtualNetworks/",
    var.hub_virtual_network_name
  ])

  private_dns_resource_group_scope = join("", [
    "/subscriptions/",
    var.connectivity_subscription_id,
    "/resourceGroups/",
    var.private_dns_resource_group_name
  ])

  private_dns_zone_scopes = {
    for zone_name in var.app01_private_dns_zone_names :
    zone_name => join("", [
      local.private_dns_resource_group_scope,
      "/providers/Microsoft.Network/privateDnsZones/",
      zone_name
    ])
  }

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

#
# ----------------------------------------------------------
# Connectivity - Hub VNet peering custom role
# ----------------------------------------------------------
#

resource "azurerm_role_definition" "app_hub_peering_operator" {
  name = "Application Landing Zone Hub Peering Operator"

  #
  # Define the custom role at the Hub RG scope.
  #
  scope = local.hub_resource_group_scope

  description = "Allows an Application Landing Zone Terraform identity to manage VNet peering with the regional Connectivity Hub."

  permissions {
    actions = [
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/peer/action",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/delete"
    ]

    not_actions = []
    
  }

  assignable_scopes = [
    local.hub_resource_group_scope
  ]
}

resource "azurerm_role_assignment" "apply_hub_peering_operator" {
  scope = local.hub_virtual_network_scope

  role_definition_id = azurerm_role_definition.app_hub_peering_operator.role_definition_resource_id

  principal_id   = azurerm_user_assigned_identity.apply.principal_id
  principal_type = "ServicePrincipal"
}

resource "azurerm_role_assignment" "plan_connectivity_hub_reader" {
  scope = local.hub_resource_group_scope

  role_definition_name = "Reader"

  principal_id   = azurerm_user_assigned_identity.plan.principal_id
  principal_type = "ServicePrincipal"
}

#
# ----------------------------------------------------------
# Connectivity - Private DNS integration custom role
# ----------------------------------------------------------
#

resource "azurerm_role_definition" "app_private_dns_integration_operator" {
  name = "Application Landing Zone Private DNS Integration Operator"

  scope = local.private_dns_resource_group_scope

  description = "Allows an Application Landing Zone Terraform identity to link its VNet and Private Endpoints with approved central Private DNS zones."

  permissions {
    actions = [
      "Microsoft.Network/privateDnsZones/read",
      "Microsoft.Network/privateDnsZones/join/action",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/read",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/write",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/delete"
    ]

    not_actions = []
  }

  assignable_scopes = [
    local.private_dns_resource_group_scope
  ]
}

resource "azurerm_role_assignment" "apply_private_dns_integration" {
  for_each = local.private_dns_zone_scopes

  scope = each.value

  role_definition_id = azurerm_role_definition.app_private_dns_integration_operator.role_definition_resource_id

  principal_id   = azurerm_user_assigned_identity.apply.principal_id
  principal_type = "ServicePrincipal"
}

resource "azurerm_role_assignment" "plan_private_dns_reader" {
  scope = local.private_dns_resource_group_scope

  role_definition_name = "Reader"

  principal_id   = azurerm_user_assigned_identity.plan.principal_id
  principal_type = "ServicePrincipal"
}

resource "azurerm_role_assignment" "apply_private_dns_reader" {
  scope = local.private_dns_resource_group_scope

  role_definition_name = "Reader"

  principal_id   = azurerm_user_assigned_identity.apply.principal_id
  principal_type = "ServicePrincipal"
}

#
# ---------------------------------------------------------------------------------------
# The Apply Identity Needs to have ability to do Role Assignments in the App Landing Zone
# ---------------------------------------------------------------------------------------
#

resource "azurerm_role_assignment" "apply_app01_rbac_administrator" {
  scope = "/subscriptions/${var.app01_subscription_id}"

  role_definition_name = "Role Based Access Control Administrator"

  principal_id   = azurerm_user_assigned_identity.apply.principal_id
  principal_type = "ServicePrincipal"
}

