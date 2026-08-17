resource "azurerm_resource_group" "identity" {
  name     = "${var.resource_group_name}-identity"
  location = var.location
}

resource "azurerm_user_assigned_identity" "plan" {
  name                = "uami-tf-app-plan"
  resource_group_name = azurerm_resource_group.identity.name
  location            = azurerm_resource_group.identity.location
}

resource "azurerm_user_assigned_identity" "apply" {
  name                = "uami-tf-app-apply"
  resource_group_name = azurerm_resource_group.identity.name
  location            = azurerm_resource_group.identity.location
}