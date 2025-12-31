##############################################################################
# Azure Key Vault Module - Simplified
#
# Creates Key Vault and manages secrets from a map
##############################################################################

##############################################################################
# Data Sources
##############################################################################

data "azurerm_client_config" "current" {}

##############################################################################
# Azure Key Vault
##############################################################################

resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Enable RBAC authorization
  enable_rbac_authorization = true

  # Network rules
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

##############################################################################
# Key Vault Secrets
##############################################################################

resource "azurerm_key_vault_secret" "secrets" {
  for_each = var.secrets

  name         = each.key
  value        = each.value.value
  key_vault_id = azurerm_key_vault.main.id
}
