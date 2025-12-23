##############################################################################
# Terraform Configuration - Lab Environment
#
# Provisions K3s cluster infrastructure on a single VM
# Designed for 2 vCPU / 8GB RAM constraints
##############################################################################

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # Backend configuration for state management
  # Uncomment and configure for remote state
  # backend "s3" {
  #   bucket = "my-terraform-state"
  #   key    = "kubernetes-lab/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

##############################################################################
# Local Variables
##############################################################################

locals {
  cluster_name = "k3s-lab"
  environment  = "lab"

  # Resource constraints
  node_resources = {
    cpu_limit    = "2000m"
    memory_limit = "7Gi"  # Leave 1GB for OS
  }

  # K3s configuration
  k3s_version = "v1.30.0+k3s1"
  k3s_config = {
    disable = [
      "traefik",      # Using Kong instead
      "servicelb",    # Using MetalLB
      "local-storage" # Using custom storage provisioner
    ]
    write-kubeconfig-mode = "0644"
  }

  # Network configuration
  network = {
    pod_cidr     = "10.42.0.0/16"
    service_cidr = "10.43.0.0/16"
    cluster_dns  = "10.43.0.10"
  }

  # Tags for resource management
  common_tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
    Project     = "kubernetes-extreme-lab"
    Owner       = "platform-team"
  }
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

  tags = local.common_tags
}

##############################################################################
# Networking Module (Optional - for cloud deployments)
##############################################################################

# module "networking" {
#   source = "../../modules/networking"
#
#   cluster_name = local.cluster_name
#   environment  = local.environment
#
#   # Network configuration
#   vpc_cidr = "10.0.0.0/16"
#
#   tags = local.common_tags
# }

##############################################################################
# Storage Module (Optional)
##############################################################################

# module "storage" {
#   source = "../../modules/storage"
#
#   cluster_name = local.cluster_name
#   environment  = local.environment
#
#   storage_class_name = "local-path"
#
#   tags = local.common_tags
# }

##############################################################################
# Local K3s Installation (Docker-based for lab)
##############################################################################

resource "null_resource" "k3s_installation" {
  depends_on = [module.k3s_cluster]

  provisioner "local-exec" {
    command = <<-EOT
      echo "K3s cluster configuration generated"
      echo "Run: ansible-playbook -i ../../ansible/inventory/lab.ini ../../ansible/playbooks/k3s-install.yaml"
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

##############################################################################
# Generate Ansible Inventory
##############################################################################

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../../ansible/inventory/lab.ini"
  content  = templatefile("${path.module}/templates/inventory.tpl", {
    cluster_name = local.cluster_name
    environment  = local.environment
    k3s_version  = local.k3s_version
    pod_cidr     = local.network.pod_cidr
    service_cidr = local.network.service_cidr
  })

  file_permission = "0644"
}

##############################################################################
# Generate kubeconfig placeholder
##############################################################################

resource "local_file" "kubeconfig_readme" {
  filename = "${path.module}/kubeconfig-README.md"
  content  = <<-EOT
    # Kubeconfig Setup

    After K3s installation, kubeconfig will be available at:
    - Default: `/etc/rancher/k3s/k3s.yaml`
    - User: `~/.kube/config`

    ## Export kubeconfig:
    ```bash
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    ```

    ## Or copy to default location:
    ```bash
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    ```

    ## Verify:
    ```bash
    kubectl cluster-info
    kubectl get nodes
    ```
  EOT

  file_permission = "0644"
}
