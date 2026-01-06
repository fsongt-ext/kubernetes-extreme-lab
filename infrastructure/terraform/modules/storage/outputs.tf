output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.this.name
}

output "primary_access_key" {
  description = "Primary access key for the storage account"
  value       = azurerm_storage_account.this.primary_access_key
  sensitive   = true
}

output "secondary_access_key" {
  description = "Secondary access key for the storage account"
  value       = azurerm_storage_account.this.secondary_access_key
  sensitive   = true
}

output "primary_connection_string" {
  description = "Primary connection string for the storage account"
  value       = azurerm_storage_account.this.primary_connection_string
  sensitive   = true
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint URL"
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "primary_web_endpoint" {
  description = "Primary web endpoint URL (for static website)"
  value       = azurerm_storage_account.this.primary_web_endpoint
}

output "container_name" {
  description = "Name of the Helm charts container"
  value       = azurerm_storage_container.helm_charts.name
}

output "helm_repo_url" {
  description = "Helm repository URL"
  value       = "${azurerm_storage_account.this.primary_web_endpoint}"
}

output "helm_repo_url_blob" {
  description = "Helm repository URL (blob endpoint)"
  value       = "${azurerm_storage_account.this.primary_blob_endpoint}${azurerm_storage_container.helm_charts.name}"
}
