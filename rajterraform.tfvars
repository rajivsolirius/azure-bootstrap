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
# Private DNS zones that App001 is permitted to integrate with.
#
app01_private_dns_zone_names = [
  "privatelink.vaultcore.azure.net"
]