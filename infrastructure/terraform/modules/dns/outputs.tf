##############################################################################
# DNS Module Outputs
##############################################################################

output "dns_zone_id" {
  description = "The ID of the DNS zone"
  value       = azurerm_dns_zone.main.id
}

output "dns_zone_name" {
  description = "The name of the DNS zone"
  value       = azurerm_dns_zone.main.name
}

output "name_servers" {
  description = "The name servers for the DNS zone"
  value       = azurerm_dns_zone.main.name_servers
}

output "a_record_fqdns" {
  description = "Map of A record names to their FQDNs"
  value = {
    for k, v in azurerm_dns_a_record.records : k => v.fqdn
  }
}

output "cname_record_fqdns" {
  description = "Map of CNAME record names to their FQDNs"
  value = {
    for k, v in azurerm_dns_cname_record.records : k => v.fqdn
  }
}
