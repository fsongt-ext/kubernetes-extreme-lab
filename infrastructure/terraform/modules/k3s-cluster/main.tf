##############################################################################
# K3s Cluster Module
#
# Manages K3s cluster configuration and setup
##############################################################################

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

##############################################################################
# Variables
##############################################################################

variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "k3s_version" {
  description = "K3s version to install"
  type        = string
}

variable "pod_cidr" {
  description = "CIDR for pod network"
  type        = string
}

variable "service_cidr" {
  description = "CIDR for service network"
  type        = string
}

variable "cluster_dns" {
  description = "Cluster DNS IP"
  type        = string
}

variable "disable_components" {
  description = "List of K3s components to disable"
  type        = list(string)
  default     = []
}

variable "node_cpu_limit" {
  description = "CPU limit for nodes"
  type        = string
}

variable "node_memory_limit" {
  description = "Memory limit for nodes"
  type        = string
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}

##############################################################################
# Local Variables
##############################################################################

locals {
  k3s_config = {
    cluster-cidr      = var.pod_cidr
    service-cidr      = var.service_cidr
    cluster-dns       = var.cluster_dns
    disable           = join(",", var.disable_components)
    write-kubeconfig-mode = "0644"
  }
}

##############################################################################
# K3s Configuration File
##############################################################################

resource "local_file" "k3s_config" {
  filename = "${path.module}/generated/k3s-config.yaml"
  content  = yamlencode({
    cluster-cidr = local.k3s_config.cluster-cidr
    service-cidr = local.k3s_config.service-cidr
    cluster-dns  = local.k3s_config.cluster-dns
    disable      = var.disable_components
    write-kubeconfig-mode = local.k3s_config.write-kubeconfig-mode

    # Security settings
    secrets-encryption = true
    protect-kernel-defaults = true

    # Audit logging
    kube-apiserver-arg = [
      "audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log",
      "audit-log-maxage=30",
      "audit-log-maxbackup=10",
      "audit-log-maxsize=100"
    ]
  })

  file_permission = "0644"
}

##############################################################################
# Outputs
##############################################################################

output "cluster_name" {
  description = "Cluster name"
  value       = var.cluster_name
}

output "k3s_config_path" {
  description = "Path to K3s configuration file"
  value       = local_file.k3s_config.filename
}

output "cluster_config" {
  description = "Cluster configuration"
  value = {
    pod_cidr     = var.pod_cidr
    service_cidr = var.service_cidr
    cluster_dns  = var.cluster_dns
  }
}
