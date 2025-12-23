##############################################################################
# Terraform Variables - Lab Environment
##############################################################################

variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "k3s-lab"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name))
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"

  validation {
    condition     = contains(["lab", "dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: lab, dev, staging, prod."
  }
}

variable "k3s_version" {
  description = "K3s version to install"
  type        = string
  default     = "v1.30.0+k3s1"
}

variable "node_cpu_limit" {
  description = "CPU limit for K3s node (e.g., '2000m')"
  type        = string
  default     = "2000m"
}

variable "node_memory_limit" {
  description = "Memory limit for K3s node (e.g., '7Gi')"
  type        = string
  default     = "7Gi"
}

variable "pod_cidr" {
  description = "CIDR block for pod network"
  type        = string
  default     = "10.42.0.0/16"

  validation {
    condition     = can(cidrhost(var.pod_cidr, 0))
    error_message = "Pod CIDR must be a valid IPv4 CIDR block."
  }
}

variable "service_cidr" {
  description = "CIDR block for service network"
  type        = string
  default     = "10.43.0.0/16"

  validation {
    condition     = can(cidrhost(var.service_cidr, 0))
    error_message = "Service CIDR must be a valid IPv4 CIDR block."
  }
}

variable "disable_traefik" {
  description = "Disable default Traefik ingress controller"
  type        = bool
  default     = true
}

variable "disable_servicelb" {
  description = "Disable default ServiceLB"
  type        = bool
  default     = true
}

variable "enable_secrets_encryption" {
  description = "Enable secrets encryption at rest"
  type        = bool
  default     = true
}

variable "enable_audit_logging" {
  description = "Enable Kubernetes audit logging"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
