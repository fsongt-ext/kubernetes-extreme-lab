package kubernetes.admission

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Enforce security best practices for pods

# Deny pods running as root
deny[msg] {
	input.request.kind.kind == "Pod"
	input.request.operation in ["CREATE", "UPDATE"]

	# Check pod-level security context
	not input.request.object.spec.securityContext.runAsNonRoot

	msg := "Pod must set securityContext.runAsNonRoot=true at pod level"
}

# Deny containers running as root
deny[msg] {
	input.request.kind.kind == "Pod"
	input.request.operation in ["CREATE", "UPDATE"]

	some container in input.request.object.spec.containers

	# Check container-level security context
	sc := container.securityContext
	not sc.runAsNonRoot

	msg := sprintf("Container %s must set securityContext.runAsNonRoot=true", [container.name])
}

# Deny privileged containers
deny[msg] {
	input.request.kind.kind == "Pod"
	input.request.operation in ["CREATE", "UPDATE"]

	some container in input.request.object.spec.containers
	container.securityContext.privileged == true

	msg := sprintf("Container %s cannot run in privileged mode", [container.name])
}

# Enforce read-only root filesystem
deny[msg] {
	input.request.kind.kind == "Pod"
	input.request.operation in ["CREATE", "UPDATE"]

	some container in input.request.object.spec.containers
	not container.securityContext.readOnlyRootFilesystem

	msg := sprintf("Container %s must use read-only root filesystem", [container.name])
}

# Deny host network access
deny[msg] {
	input.request.kind.kind == "Pod"
	input.request.operation in ["CREATE", "UPDATE"]

	input.request.object.spec.hostNetwork == true

	msg := "Pod cannot use host network"
}

# Deny host PID namespace
deny[msg] {
	input.request.kind.kind == "Pod"
	input.request.operation in ["CREATE", "UPDATE"]

	input.request.object.spec.hostPID == true

	msg := "Pod cannot use host PID namespace"
}

# Deny host IPC namespace
deny[msg] {
	input.request.kind.kind == "Pod"
	input.request.operation in ["CREATE", "UPDATE"]

	input.request.object.spec.hostIPC == true

	msg := "Pod cannot use host IPC namespace"
}

# Deny dangerous capabilities
deny[msg] {
	input.request.kind.kind == "Pod"
	input.request.operation in ["CREATE", "UPDATE"]

	dangerous_capabilities := {"SYS_ADMIN", "NET_ADMIN", "SYS_MODULE", "SYS_RAWIO"}

	some container in input.request.object.spec.containers
	some cap in container.securityContext.capabilities.add
	cap in dangerous_capabilities

	msg := sprintf("Container %s cannot add dangerous capability: %s", [container.name, cap])
}

# Require all capabilities to be dropped
deny[msg] {
	input.request.kind.kind == "Pod"
	input.request.operation in ["CREATE", "UPDATE"]

	some container in input.request.object.spec.containers
	not has_drop_all(container)

	msg := sprintf("Container %s must drop all capabilities", [container.name])
}

has_drop_all(container) {
	container.securityContext.capabilities.drop[_] == "ALL"
}

# Deny privilege escalation
deny[msg] {
	input.request.kind.kind == "Pod"
	input.request.operation in ["CREATE", "UPDATE"]

	some container in input.request.object.spec.containers
	container.securityContext.allowPrivilegeEscalation == true

	msg := sprintf("Container %s must set allowPrivilegeEscalation=false", [container.name])
}

# Enforce seccomp profile
warn[msg] {
	input.request.kind.kind == "Pod"
	input.request.operation in ["CREATE", "UPDATE"]

	not input.request.object.spec.securityContext.seccompProfile

	msg := "Pod should define seccompProfile (RuntimeDefault or Localhost)"
}
