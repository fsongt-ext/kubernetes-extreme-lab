##############################################################################
# ACR Module Variables
##############################################################################

variable "acr_name" {
  description = "Name of the Azure Container Registry (must be globally unique, alphanumeric only)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]+$", var.acr_name))
    error_message = "ACR name must contain only alphanumeric characters."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the ACR"
  type        = string
}

variable "sku" {
  description = "SKU tier for ACR (Basic, Standard, Premium)"
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "SKU must be Basic, Standard, or Premium."
  }
}

variable "admin_enabled" {
  description = "Enable admin user for ACR"
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Enable public network access"
  type        = bool
  default     = true
}

variable "anonymous_pull_enabled" {
  description = "Enable anonymous pull (makes registry public)"
  type        = bool
  default     = false
}

variable "network_rule_set" {
  description = "Network rule set for ACR"
  type = object({
    default_action = string
    ip_rules       = list(string)
  })
  default = null
}

variable "georeplications" {
  description = "Geo-replication locations (Premium SKU only)"
  type = list(object({
    location                = string
    zone_redundancy_enabled = bool
    tags                    = map(string)
  }))
  default = []
}

variable "pull_role_assignments" {
  description = "Map of principal IDs to grant AcrPull role"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to ACR"
  type        = map(string)
  default     = {}
}
