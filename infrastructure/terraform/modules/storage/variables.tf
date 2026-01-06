variable "storage_account_name" {
  description = "Name of the storage account (must be globally unique, 3-24 chars, lowercase alphanumeric)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 characters, lowercase letters and numbers only."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the storage account"
  type        = string
}

variable "account_tier" {
  description = "Storage account tier (Standard or Premium)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.account_tier)
    error_message = "Account tier must be either Standard or Premium."
  }
}

variable "replication_type" {
  description = "Storage account replication type (LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS)"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.replication_type)
    error_message = "Invalid replication type."
  }
}

variable "account_kind" {
  description = "Storage account kind (BlobStorage, StorageV2, etc.)"
  type        = string
  default     = "StorageV2"
}

variable "container_name" {
  description = "Name of the blob container for Helm charts"
  type        = string
  default     = "helm-charts"
}

variable "container_access_type" {
  description = "Access level for the container (private, blob, container)"
  type        = string
  default     = "blob"

  validation {
    condition     = contains(["private", "blob", "container"], var.container_access_type)
    error_message = "Container access type must be private, blob, or container."
  }
}

variable "public_network_access_enabled" {
  description = "Enable public network access to storage account"
  type        = bool
  default     = true
}

variable "allow_public_containers" {
  description = "Allow containers to have public access"
  type        = bool
  default     = true
}

variable "versioning_enabled" {
  description = "Enable blob versioning"
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted blobs (0 to disable)"
  type        = number
  default     = 7

  validation {
    condition     = var.soft_delete_retention_days >= 0 && var.soft_delete_retention_days <= 365
    error_message = "Soft delete retention must be between 0 and 365 days."
  }
}

variable "enable_lifecycle_policy" {
  description = "Enable lifecycle management policy"
  type        = bool
  default     = true
}

variable "index_document" {
  description = "Index document for static website (for Helm repo browsing)"
  type        = string
  default     = "index.yaml"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
