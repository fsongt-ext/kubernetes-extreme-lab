##############################################################################
# Azure Container Registry Module
##############################################################################

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = var.admin_enabled

  # Public network access
  public_network_access_enabled = var.public_network_access_enabled

  dynamic "network_rule_set" {
    for_each = var.network_rule_set != null ? [var.network_rule_set] : []
    content {
      default_action = network_rule_set.value.default_action

      dynamic "ip_rule" {
        for_each = network_rule_set.value.ip_rules
        content {
          action   = "Allow"
          ip_range = ip_rule.value
        }
      }
    }
  }

  # Georeplications (for Premium SKU only)
  dynamic "georeplications" {
    for_each = var.georeplications
    content {
      location                = georeplications.value.location
      zone_redundancy_enabled = georeplications.value.zone_redundancy_enabled
      tags                    = georeplications.value.tags
    }
  }

  tags = var.tags
}

