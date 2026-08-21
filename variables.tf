variable "management_subscription_id" {
  description = "Subscription ID of the Management subscription."
  type        = string
}

variable "app01_subscription_id" {
  description = "Subscription ID of Application Landing Zone 01."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "uksouth"
}

variable "resource_group_name" {
  description = "Base resource group name used by the Application Terraform bootstrap resources."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Resource ID of the existing Private Endpoint subnet."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Resource ID of the existing privatelink.blob.core.windows.net Private DNS Zone."
  type        = string
}

variable "app01_state_storage_account_name" {
  description = "Storage Account name for the App01 Terraform state."
  type        = string
}

variable "bootstrap_backend_resource_group_name" {
  description = "Resource Group containing the Application bootstrap Terraform backend."
  type        = string
}

variable "bootstrap_backend_storage_account_name" {
  description = "Storage Account containing the Application bootstrap Terraform state."
  type        = string
}

#
# ----------------------------------------------------------
# Connectivity subscription / shared network resources
# ----------------------------------------------------------
#

variable "connectivity_subscription_id" {
  description = "Subscription ID of the Connectivity subscription."
  type        = string
}

variable "hub_virtual_network_resource_group_name" {
  description = "Resource Group containing the regional Connectivity Hub VNet."
  type        = string
}

variable "hub_virtual_network_name" {
  description = "Name of the regional Connectivity Hub VNet."
  type        = string
}

variable "private_dns_resource_group_name" {
  description = "Resource Group containing the centrally managed Private DNS zones."
  type        = string
}

variable "app01_private_dns_zone_names" {
  description = "Private DNS zones that App01 Terraform is permitted to integrate with."
  type        = set(string)

  default = [
    "privatelink.vaultcore.azure.net"
  ]
}