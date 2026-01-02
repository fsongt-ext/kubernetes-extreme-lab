##############################################################################
# Azure Resource Group
##############################################################################

resource "azurerm_resource_group" "main" {
  name     = "${local.cluster_name}-rg"
  location = local.azure.location

  tags = local.common_tags
}

##############################################################################
# Network Module - Azure VNet and Subnet
##############################################################################

module "network" {
  source = "../../modules/networking"

  cluster_name        = local.cluster_name
  environment         = local.environment
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  vnet_cidr   = local.network.vnet_cidr
  subnet_cidr = local.network.subnet_cidr

  tags       = local.common_tags
  depends_on = [azurerm_resource_group.main]
}

##############################################################################
# Azure Container Registry Module
##############################################################################

module "acr" {
  source = "../../modules/acr"

  acr_name            = local.acr_config.name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  # Public registry configuration
  sku                           = "Basic"
  admin_enabled                 = true # Enable for easier K3s integration
  public_network_access_enabled = true
  anonymous_pull_enabled        = true # Makes it public

  tags       = local.common_tags
  depends_on = [azurerm_resource_group.main]
}

resource "azurerm_role_assignment" "vm_acr_pull" {
  scope                = module.acr.acr_id
  role_definition_name = "AcrPull"
  principal_id         = module.vm.managed_identity_principal_id

  depends_on = [module.acr, module.vm]
}

#############################################################################
# VM Module - K3s Master Node
#############################################################################

module "vm" {
  source = "../../modules/vm"

  vm_name             = "${local.cluster_name}-master"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = module.network.subnet_id
  public_ip_enabled   = true

  # VM Configuration
  vm_size        = local.azure.vm_size
  admin_username = var.admin_username

  # SSH Key
  ssh_public_key = file(var.ssh_public_key_path)

  # OS Disk
  os_disk_type    = var.os_disk_type
  os_disk_size_gb = var.os_disk_size_gb

  # Ubuntu 22.04 LTS
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"
  image_version   = "latest"

  tags = merge(
    local.common_tags,
    {
      Role = "master"
    }
  )
  depends_on = [module.network]
}

##############################################################################
# Azure Key Vault Modules
##############################################################################

# Grant the yourself rights to manage Key Vault secrets
resource "azurerm_role_assignment" "terraform_kv_secrets_officer" {
  scope                = resource.azurerm_resource_group.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

module "keyvaults" {
  source   = "../../modules/keyvault"
  for_each = local.keyvaults

  key_vault_name      = "${local.cluster_name}-${each.key}-${each.value.name_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  secrets             = each.value.secrets

  tags       = local.common_tags
  depends_on = [azurerm_role_assignment.terraform_kv_secrets_officer]
}

resource "azurerm_role_assignment" "vm_kv_secrets_user" {
  for_each = module.keyvaults

  scope                = each.value.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.vm.managed_identity_principal_id
}


##############################################################################
# K3s Cluster Module
##############################################################################

module "k3s_cluster" {
  source = "../../modules/k3s-cluster"

  cluster_name = local.cluster_name
  environment  = local.environment
  k3s_version  = local.k3s_version

  # Network configuration
  pod_cidr     = local.network.pod_cidr
  service_cidr = local.network.service_cidr
  cluster_dns  = local.network.cluster_dns

  # Disable default components
  disable_components = local.k3s_config.disable

  # Resource constraints
  node_cpu_limit    = local.node_resources.cpu_limit
  node_memory_limit = local.node_resources.memory_limit

  tags       = local.common_tags
  depends_on = [module.vm]
}

##############################################################################
# DNS Module - Azure DNS Zone
##############################################################################

module "dns" {
  source = "../../modules/dns"

  domain_name         = local.domain
  resource_group_name = azurerm_resource_group.main.name

  # A Records - Point to VM public IP
  a_records = {
    "auth" = {
      ttl     = 300
      records = [module.vm.public_ip_address]
    }
    # Root domain (optional)
    "@" = {
      ttl     = 300
      records = [module.vm.public_ip_address]
    }
    "argocd" = {
      ttl     = 300
      records = [module.vm.public_ip_address]
    }
    "grafana" = {
      ttl     = 300
      records = [module.vm.public_ip_address]
    }
  }

  # CNAME Records (optional - for additional subdomains)
  cname_records = {
    # Example: "www" = {
    #   ttl    = 300
    #   record = local.domain
    # }
  }

  tags       = local.common_tags
  depends_on = [azurerm_resource_group.main, module.vm]
}
