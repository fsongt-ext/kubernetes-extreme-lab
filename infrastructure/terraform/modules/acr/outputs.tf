##############################################################################
# ACR Module Outputs
##############################################################################

output "acr_id" {
  description = "ID of the Azure Container Registry"
  value       = azurerm_container_registry.acr.id
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.acr.name
}

output "login_server" {
  description = "Login server URL for the ACR"
  value       = azurerm_container_registry.acr.login_server
}

output "admin_username" {
  description = "Admin username for ACR (if admin enabled)"
  value       = var.admin_enabled ? azurerm_container_registry.acr.admin_username : null
  sensitive   = true
}

output "admin_password" {
  description = "Admin password for ACR (if admin enabled)"
  value       = var.admin_enabled ? azurerm_container_registry.acr.admin_password : null
  sensitive   = true
}
