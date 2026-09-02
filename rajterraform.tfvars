#
# ----------------------------------------------------------
# Connectivity
# ----------------------------------------------------------
#

connectivity_subscription_id = "<CONNECTIVITY-SUBSCRIPTION-ID>"

hub_virtual_network_resource_group_name = "rg-hub-uksouth"

hub_virtual_network_name = "vnet-hub-uksouth"

private_dns_resource_group_name = "<CENTRAL-PRIVATE-DNS-RESOURCE-GROUP>"


#
# Private DNS zones that App Landing Zones are permitted to integrate with.
#
application_private_dns_zone_names = [
  "privatelink.vaultcore.azure.net",
  "privatelink.uks.backup.windowsazure.com",
  "privatelink.blob.core.windows.net",
  "privatelink.queue.core.windows.net",
  "privatelink.servicebus.windows.net"
]

application_landing_zones = {
  app01 = {
    subscription_id            = "<APP01-SUBSCRIPTION-ID>"
    state_storage_account_name = "<APP01-STATE-STORAGE-NAME>"
  }
}