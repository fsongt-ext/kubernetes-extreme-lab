##############################################################################
# Local Variables
##############################################################################

data "azurerm_client_config" "current" {}

resource "random_integer" "suffix" {
  min = 10
  max = 99
}

resource "random_password" "keycloak_admin" {
  length  = 32
  special = true
}


locals {
  cluster_name = "k3s-lab"
  environment  = "lab"
  domain       = "fresherintern.cloud"

  # Azure configuration
  azure = {
    location = "southeastasia"
    vm_size  = "Standard_B2ms" # 2 vCPU, 8GB RAM
  }

  # Resource constraints
  node_resources = {
    cpu_limit    = "2000m"
    memory_limit = "7Gi" # Leave 1GB for OS
  }

  # K3s configuration
  k3s_version = "v1.30.0+k3s1"
  k3s_config = {
    disable = [
      "traefik",   # Using Kong instead
      "servicelb", # Using MetalLB
    ]
    write-kubeconfig-mode = "0644"
    flannel-backend       = "none" # Disabled - using Cilium instead
  }

  acr_config = {
    name = "k3slabacr${random_integer.suffix.result}"
  }

  # Keycloak configuration
  keycloak_version = "26.0.7"

  # Network configuration
  network = {
    vnet_cidr    = "10.0.0.0/16"
    subnet_cidr  = "10.0.1.0/24"
    pod_cidr     = "10.42.0.0/16"
    service_cidr = "10.43.0.0/16"
    cluster_dns  = "10.43.0.10"
  }

  # Keyvault configuration
  keyvaults = {
    "vm-kv" = {
      name_suffix = random_integer.suffix.result
      secrets = {
        "KC-BOOTSTRAP-ADMIN-USERNAME" = {
          value = "admin"
        }
        "KC-BOOTSTRAP-ADMIN-PASSWORD" = {
          value = random_password.keycloak_admin.result
        }
        "ACR-LOGIN-SERVER" = {
          value = module.acr.login_server
        }
        "ACR-ADMIN-USERNAME" = {
          value = module.acr.admin_username
        }
        "ACR-ADMIN-PASSWORD" = {
          value = module.acr.admin_password
        }
      }
    }
  }

  # Tags for resource management
  common_tags = {
    vironment = local.environment
    ManagedBy = "terraform"
    oject     = "kubernetes-extreme-lab"
    Owner     = "platform-team"
  }
}
