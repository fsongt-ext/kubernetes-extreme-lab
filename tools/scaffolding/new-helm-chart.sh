#!/usr/bin/env bash
# Scaffold a new Helm chart for application deployment

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    warn "Helm is not installed. Install it from https://helm.sh/docs/intro/install/"
    exit 1
fi

# Get chart name
if [ $# -eq 0 ]; then
    read -rp "Enter chart name: " CHART_NAME
else
    CHART_NAME=$1
fi

# Validate chart name
if [ -z "$CHART_NAME" ]; then
    warn "Chart name cannot be empty"
    exit 1
fi

CHART_DIR="applications/helm-charts/$CHART_NAME"

if [ -d "$CHART_DIR" ]; then
    warn "Chart $CHART_NAME already exists at $CHART_DIR"
    exit 1
fi

log "Creating Helm chart: $CHART_NAME"

# Create chart using helm create
helm create "$CHART_DIR"

# Customize Chart.yaml
cat > "$CHART_DIR/Chart.yaml" <<EOF
apiVersion: v2
name: $CHART_NAME
description: A Helm chart for $CHART_NAME on Kubernetes
type: application
version: 0.1.0
appVersion: "1.0.0"

keywords:
  - $CHART_NAME
  - kubernetes

maintainers:
  - name: Platform Team
    email: platform@example.com

# Dependencies (uncomment if needed)
# dependencies:
#   - name: postgresql
#     version: 12.1.0
#     repository: https://charts.bitnami.com/bitnami
#     condition: postgresql.enabled
EOF

# Create customized values.yaml
cat > "$CHART_DIR/values.yaml" <<EOF
# Default values for $CHART_NAME

replicaCount: 1

image:
  repository: $CHART_NAME
  pullPolicy: IfNotPresent
  tag: "1.0.0"

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations: {}
  name: ""

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 65534
  fsGroup: 65534
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true

service:
  type: ClusterIP
  port: 8080
  targetPort: 8080
  annotations: {}

ingress:
  enabled: false
  className: "kong"
  annotations: {}
  hosts:
    - host: $CHART_NAME.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity: {}

# Istio configuration
istio:
  enabled: true
  gateway:
    enabled: false
    hosts:
      - "$CHART_NAME.local"
  virtualService:
    enabled: true
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: 5xx,reset,connect-failure
    timeout: 10s
    corsPolicy:
      allowOrigins:
        - exact: "*"
      allowMethods:
        - GET
        - POST
        - PUT
        - DELETE
      allowHeaders:
        - content-type
      maxAge: 24h

# Observability
monitoring:
  serviceMonitor:
    enabled: true
    interval: 30s

# Network policies
networkPolicy:
  enabled: true
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: istio-system
  egress:
    - to:
      - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443

# Environment-specific overrides will be in values-{env}.yaml
EOF

# Create values-lab.yaml
cat > "$CHART_DIR/values-lab.yaml" <<EOF
# Lab environment overrides

replicaCount: 1

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi

autoscaling:
  enabled: false
EOF

# Create deployment template with Argo Rollout
cat > "$CHART_DIR/templates/rollout.yaml" <<'EOF'
{{- if .Values.rollout.enabled }}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: {{ include "CHART_NAME.fullname" . }}
  labels:
    {{- include "CHART_NAME.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      {{- include "CHART_NAME.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "CHART_NAME.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "CHART_NAME.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          {{- with .Values.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause: {duration: 1m}
        - setWeight: 40
        - pause: {duration: 1m}
        - setWeight: 60
        - pause: {duration: 1m}
        - setWeight: 80
        - pause: {duration: 1m}
      canaryService: {{ include "CHART_NAME.fullname" . }}-canary
      stableService: {{ include "CHART_NAME.fullname" . }}-stable
{{- else }}
# Standard Deployment when Rollout is disabled
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "CHART_NAME.fullname" . }}
  labels:
    {{- include "CHART_NAME.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "CHART_NAME.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "CHART_NAME.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "CHART_NAME.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /health
              port: http
          readinessProbe:
            httpGet:
              path: /health
              port: http
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
{{- end }}
EOF

# Replace CHART_NAME placeholder
sed -i.bak "s/CHART_NAME/$CHART_NAME/g" "$CHART_DIR/templates/rollout.yaml" && rm "$CHART_DIR/templates/rollout.yaml.bak"

log "Helm chart created at: $CHART_DIR"
log ""
log "Next steps:"
log "  1. Customize values in $CHART_DIR/values.yaml"
log "  2. Add additional templates to $CHART_DIR/templates/"
log "  3. Create ArgoCD Application in gitops/environments/lab/applications/$CHART_NAME.yaml"
log "  4. Commit and push to trigger deployment"
