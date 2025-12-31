##############################################################################
# Azure DNS Zone Module
##############################################################################

resource "azurerm_dns_zone" "main" {
  name                = var.domain_name
  resource_group_name = var.resource_group_name

  tags = var.tags
}

##############################################################################
# DNS A Records
##############################################################################

resource "azurerm_dns_a_record" "records" {
  for_each = var.a_records

  name                = each.key
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = var.resource_group_name
  ttl                 = each.value.ttl
  records             = each.value.records

  tags = var.tags
}

##############################################################################
# DNS CNAME Records
##############################################################################

resource "azurerm_dns_cname_record" "records" {
  for_each = var.cname_records

  name                = each.key
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = var.resource_group_name
  ttl                 = each.value.ttl
  record              = each.value.record

  tags = var.tags
}

##############################################################################
# DNS TXT Records (for verification, SPF, etc.)
##############################################################################

resource "azurerm_dns_txt_record" "records" {
  for_each = var.txt_records

  name                = each.key
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = var.resource_group_name
  ttl                 = each.value.ttl

  dynamic "record" {
    for_each = each.value.records
    content {
      value = record.value
    }
  }

  tags = var.tags
}
