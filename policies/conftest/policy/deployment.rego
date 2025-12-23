package main

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Conftest policy for validating Kubernetes Deployments
# Run with: conftest test deployment.yaml -p policy/

deny[msg] {
	input.kind == "Deployment"
	not input.spec.template.spec.securityContext.runAsNonRoot
	msg := "Deployment must run as non-root"
}

deny[msg] {
	input.kind == "Deployment"
	input.spec.replicas == 1
	msg := "Deployment should have more than 1 replica for HA"
}

deny[msg] {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	not container.resources.limits.memory
	msg := sprintf("Container %s must specify memory limits", [container.name])
}

deny[msg] {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	not container.resources.limits.cpu
	msg := sprintf("Container %s must specify CPU limits", [container.name])
}

warn[msg] {
	input.kind == "Deployment"
	not input.spec.template.spec.affinity
	msg := "Deployment should specify pod affinity/anti-affinity rules"
}

warn[msg] {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	not container.livenessProbe
	msg := sprintf("Container %s should have liveness probe", [container.name])
}

warn[msg] {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	not container.readinessProbe
	msg := sprintf("Container %s should have readiness probe", [container.name])
}

# Validate image registry
deny[msg] {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	image := container.image

	allowed_registries := {"ghcr.io", "gcr.io", "docker.io", "quay.io", "localhost"}

	not any_allowed_registry(image, allowed_registries)

	msg := sprintf("Container %s uses image from untrusted registry: %s", [container.name, image])
}

any_allowed_registry(image, registries) {
	registry := registries[_]
	startswith(image, registry)
}
