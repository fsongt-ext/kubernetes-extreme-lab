##############################################################################
# Terraform Outputs - Lab Environment
##############################################################################

output "cluster_name" {
  description = "Name of the K3s cluster"
  value       = local.cluster_name
}

output "environment" {
  description = "Environment name"
  value       = local.environment
}

output "k3s_version" {
  description = "K3s version"
  value       = local.k3s_version
}

output "network_configuration" {
  description = "Network configuration for the cluster"
  value = {
    pod_cidr     = local.network.pod_cidr
    service_cidr = local.network.service_cidr
    cluster_dns  = local.network.cluster_dns
  }
}

output "resource_limits" {
  description = "Resource limits for cluster nodes"
  value = {
    cpu    = local.node_resources.cpu_limit
    memory = local.node_resources.memory_limit
  }
}

output "ansible_inventory_path" {
  description = "Path to generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}

output "kubeconfig_instructions" {
  description = "Instructions for accessing kubeconfig"
  value       = <<-EOT
    After K3s installation:
    1. Export kubeconfig: export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    2. Or copy to ~/.kube/config
    3. Verify: kubectl cluster-info
  EOT
}

output "next_steps" {
  description = "Next steps after Terraform apply"
  value       = <<-EOT
    1. Review generated Ansible inventory: ${local_file.ansible_inventory.filename}
    2. Run Ansible playbook:
       cd ../../ansible
       ansible-playbook -i inventory/lab.ini playbooks/k3s-install.yaml
    3. Verify cluster:
       kubectl get nodes
       kubectl get pods -A
  EOT
}
