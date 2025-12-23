package main

import future.keywords.if

# Conftest policy for validating Terraform plans
# Run with: terraform plan -out=tfplan.binary && terraform show -json tfplan.binary | conftest test -

deny[msg] {
	resource := input.planned_values.root_module.resources[_]
	resource.type == "kubernetes_pod"

	container := resource.values.spec[0].container[_]
	container.security_context[0].privileged == true

	msg := sprintf("Pod %s has privileged container which is not allowed", [resource.name])
}

deny[msg] {
	resource := input.planned_values.root_module.resources[_]
	resource.type == "kubernetes_pod"

	container := resource.values.spec[0].container[_]
	container.image_pull_policy == "Always"

	msg := sprintf("Container in pod %s uses imagePullPolicy: Always which may cause rate limiting", [resource.name])
}

warn[msg] {
	resource := input.planned_values.root_module.resources[_]
	resource.type == "kubernetes_namespace"

	not resource.values.metadata[0].labels

	msg := sprintf("Namespace %s should have labels for organization", [resource.name])
}

# Validate resource tags
deny[msg] {
	resource := input.planned_values.root_module.resources[_]
	resource.type == "aws_instance"

	required_tags := {"Environment", "Team", "CostCenter"}
	existing_tags := {tag | resource.values.tags[tag]}
	missing_tags := required_tags - existing_tags

	count(missing_tags) > 0

	msg := sprintf("AWS instance %s is missing required tags: %v", [resource.name, missing_tags])
}

# Validate encryption
deny[msg] {
	resource := input.planned_values.root_module.resources[_]
	resource.type == "aws_s3_bucket"

	not resource.values.server_side_encryption_configuration

	msg := sprintf("S3 bucket %s must have encryption enabled", [resource.name])
}

deny[msg] {
	resource := input.planned_values.root_module.resources[_]
	resource.type == "aws_ebs_volume"

	resource.values.encrypted == false

	msg := sprintf("EBS volume %s must be encrypted", [resource.name])
}
