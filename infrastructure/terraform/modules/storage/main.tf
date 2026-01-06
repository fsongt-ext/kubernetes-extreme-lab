##############################################################################
# Azure Storage Account for Helm Charts Repository
##############################################################################

resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_type
  account_kind             = var.account_kind

  # Enable public access for Helm repository
  public_network_access_enabled   = var.public_network_access_enabled
  allow_nested_items_to_be_public = var.allow_public_containers

  # Enable HTTPS only
  enable_https_traffic_only = true
  min_tls_version          = "TLS1_2"

  # Blob properties
  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["GET", "HEAD"]
      allowed_origins    = ["*"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }

    # Enable versioning for disaster recovery
    versioning_enabled = var.versioning_enabled

    # Lifecycle management
    dynamic "delete_retention_policy" {
      for_each = var.soft_delete_retention_days > 0 ? [1] : []
      content {
        days = var.soft_delete_retention_days
      }
    }
  }

  # Static website hosting for Helm repository
  static_website {
    index_document = var.index_document
  }

  tags = var.tags
}

##############################################################################
# Storage Container for Helm Charts
##############################################################################

resource "azurerm_storage_container" "helm_charts" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = var.container_access_type
}

##############################################################################
# Optional: CORS Configuration for direct browser access
##############################################################################

# CORS is already configured in blob_properties above

##############################################################################
# Optional: Lifecycle Management Policy
##############################################################################

resource "azurerm_storage_management_policy" "this" {
  count = var.enable_lifecycle_policy ? 1 : 0

  storage_account_id = azurerm_storage_account.this.id

  rule {
    name    = "helm-chart-lifecycle"
    enabled = true

    filters {
      prefix_match = ["charts/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        # Archive old versions after 90 days
        tier_to_archive_after_days_since_modification_greater_than = 90

        # Delete old versions after 365 days
        delete_after_days_since_modification_greater_than = 365
      }

      snapshot {
        delete_after_days_since_creation_greater_than = 30
      }

      version {
        delete_after_days_since_creation = 90
      }
    }
  }
}

##############################################################################
# Storage Account Keys (for CI/CD access)
##############################################################################

# Primary key is sensitive and will be stored in GitHub Secrets
# Access via outputs
