##############################################################################
# Key Vault Module Variables
##############################################################################

variable "key_vault_name" {
  description = "Name of the Key Vault"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "secrets" {
  description = "Map of secrets to create in the Key Vault"
  type = map(object({
    value = string
  }))
  default = {}
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
