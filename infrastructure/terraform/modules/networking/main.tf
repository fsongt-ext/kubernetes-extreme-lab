##############################################################################
# Azure Network Module
#
# Manages VNet, Subnet, and Network Security Group
##############################################################################

##############################################################################
# Virtual Network
##############################################################################


resource "azurerm_virtual_network" "main" {
  name                = "${var.cluster_name}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-vnet"
    }
  )
}

##############################################################################
# Subnet
##############################################################################

resource "azurerm_subnet" "vm_subnet" {
  name                 = "${var.cluster_name}-vm-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
}

##############################################################################
# Network Security Group
##############################################################################

resource "azurerm_network_security_group" "main" {
  name                = "${var.cluster_name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow SSH
  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTP
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTPS
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow Kubernetes API Server
  security_rule {
    name                       = "AllowK8sAPI"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-nsg"
    }
  )
}

##############################################################################
# Associate NSG with Subnet
##############################################################################

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.main.id
}
