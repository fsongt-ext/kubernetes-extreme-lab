package kubernetes.admission

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Deny pods that don't have required labels

deny[msg] {
	input.request.kind.kind == "Pod"
	input.request.operation == "CREATE"

	required_labels := {"app", "version", "team"}
	provided_labels := {label | input.request.object.metadata.labels[label]}
	missing_labels := required_labels - provided_labels

	count(missing_labels) > 0

	msg := sprintf("Pod %s is missing required labels: %v", [
		input.request.object.metadata.name,
		missing_labels,
	])
}

# Deny pods with latest tag
deny[msg] {
	input.request.kind.kind == "Pod"
	input.request.operation in ["CREATE", "UPDATE"]

	some container in input.request.object.spec.containers
	endswith(container.image, ":latest")

	msg := sprintf("Container %s uses 'latest' tag which is not allowed", [container.name])
}

# Warn about missing resource limits
warn[msg] {
	input.request.kind.kind == "Pod"
	input.request.operation == "CREATE"

	some container in input.request.object.spec.containers
	not container.resources.limits

	msg := sprintf("Container %s has no resource limits defined (warning only)", [container.name])
}
