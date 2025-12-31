##############################################################################
# VM Module Outputs
##############################################################################

output "vm_id" {
  description = "ID of the virtual machine"
  value       = azurerm_linux_virtual_machine.main.id
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = azurerm_linux_virtual_machine.main.name
}

output "public_ip_address" {
  description = "Public IP address of the VM (null if public IP is disabled)"
  value       = var.public_ip_enabled ? azurerm_public_ip.main[0].ip_address : null
}

output "private_ip_address" {
  description = "Private IP address of the VM"
  value       = azurerm_network_interface.main.private_ip_address
}

output "network_interface_id" {
  description = "ID of the network interface"
  value       = azurerm_network_interface.main.id
}

output "admin_username" {
  description = "Admin username for SSH access"
  value       = var.admin_username
}

output "managed_identity_principal_id" {
  description = "Principal ID of the VM's system assigned managed identity"
  value       = azurerm_linux_virtual_machine.main.identity[0].principal_id
}

output "managed_identity_tenant_id" {
  description = "Tenant ID of the VM's system assigned managed identity"
  value       = azurerm_linux_virtual_machine.main.identity[0].tenant_id
}

