#!/bin/bash

##############################################################################
# Update ArgoCD Admin Password
##############################################################################

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <new-password>"
    echo "Example: $0 mynewpassword"
    exit 1
fi

NEW_PASSWORD="$1"

echo "Generating bcrypt hash for password: $NEW_PASSWORD"

# Generate bcrypt hash
HASH=$(htpasswd -nbBC 10 "" "$NEW_PASSWORD" | tr -d ':\n' | sed 's/$2y/$2a/')

echo "Generated hash: $HASH"
echo ""
echo "Updating ArgoCD password..."

# Update the password in Kubernetes
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {"admin.password": "'"$HASH"'"}}'

echo ""
echo "Password updated successfully!"
echo "Username: admin"
echo "Password: $NEW_PASSWORD"
echo ""
echo "Restarting ArgoCD server to apply changes..."
kubectl rollout restart deployment argocd-server -n argocd

echo ""
echo "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo ""
echo "Done! You can now login with:"
echo "  Username: admin"
echo "  Password: $NEW_PASSWORD"
