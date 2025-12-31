##############################################################################
# Azure VM Module
#
# Manages Azure Virtual Machines with Public IP
##############################################################################

##############################################################################
# Public IP
##############################################################################


resource "azurerm_public_ip" "main" {
  count = var.public_ip_enabled ? 1 : 0

  name                = "${var.vm_name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(
    var.tags,
    {
      Name = "${var.vm_name}-pip"
    }
  )
}

##############################################################################
# Network Interface
##############################################################################

resource "azurerm_network_interface" "main" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip_enabled ? azurerm_public_ip.main[0].id : null
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.vm_name}-nic"
    }
  )
}

##############################################################################
# Virtual Machine
##############################################################################

resource "azurerm_linux_virtual_machine" "main" {
  name                = var.vm_name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  # SSH Key Authentication
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  # OS Disk
  os_disk {
    name                 = "${var.vm_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  # Source Image
  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  # Disable password authentication (SSH key only)
  disable_password_authentication = true

  # System Assigned Managed Identity for Key Vault access
  identity {
    type = "SystemAssigned"
  }

  tags = merge(
    var.tags,
    {
      Name = var.vm_name
    }
  )
}

