#!/usr/bin/env bash

##############################################################################
# Image Signing Script using Cosign
#
# Signs container images with Cosign using keyless signing (OIDC)
# or traditional key-based signing
#
# Usage:
#   ./image-sign.sh <image> [mode]
#
# Modes:
#   keyless - Use keyless signing with OIDC (default for GitHub Actions)
#   key     - Use key-based signing (requires COSIGN_KEY)
#
# Example:
#   ./image-sign.sh myapp:latest keyless
##############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Script variables
IMAGE="${1:-}"
MODE="${2:-keyless}"

# Validate inputs
if [ -z "$IMAGE" ]; then
  echo -e "${RED}Error: Image name is required${NC}"
  echo "Usage: $0 <image> [mode]"
  exit 1
fi

# Check if Cosign is installed
if ! command -v cosign &> /dev/null; then
  echo -e "${YELLOW}Cosign not found. Installing...${NC}"
  curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 \
    -o /usr/local/bin/cosign
  chmod +x /usr/local/bin/cosign
fi

echo -e "${GREEN}Signing image: $IMAGE${NC}"
echo "Mode: $MODE"
echo ""

case "$MODE" in
  keyless)
    echo -e "${GREEN}Using keyless signing (OIDC)...${NC}"

    # Keyless signing requires OIDC token from CI environment
    if [ "${CI:-false}" != "true" ] && [ -z "${COSIGN_EXPERIMENTAL:-}" ]; then
      echo -e "${YELLOW}Warning: Not in CI environment and COSIGN_EXPERIMENTAL not set${NC}"
      echo "Setting COSIGN_EXPERIMENTAL=1 for local testing"
      export COSIGN_EXPERIMENTAL=1
    fi

    cosign sign --yes "$IMAGE"

    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Image signed successfully!${NC}"

      # Verify signature
      echo -e "${GREEN}Verifying signature...${NC}"
      cosign verify "$IMAGE" \
        --certificate-identity-regexp ".*" \
        --certificate-oidc-issuer-regexp ".*" || true
    else
      echo -e "${RED}Failed to sign image${NC}"
      exit 1
    fi
    ;;

  key)
    echo -e "${GREEN}Using key-based signing...${NC}"

    if [ -z "${COSIGN_KEY:-}" ]; then
      echo -e "${RED}Error: COSIGN_KEY environment variable is required for key-based signing${NC}"
      exit 1
    fi

    # Sign with key
    echo "$COSIGN_KEY" | cosign sign --key - --yes "$IMAGE"

    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Image signed successfully with key!${NC}"

      # Verify signature
      if [ -n "${COSIGN_PUBLIC_KEY:-}" ]; then
        echo -e "${GREEN}Verifying signature...${NC}"
        echo "$COSIGN_PUBLIC_KEY" | cosign verify --key - "$IMAGE" || true
      fi
    else
      echo -e "${RED}Failed to sign image${NC}"
      exit 1
    fi
    ;;

  *)
    echo -e "${RED}Error: Invalid mode '$MODE'. Use 'keyless' or 'key'${NC}"
    exit 1
    ;;
esac

# Generate signature metadata
echo ""
echo -e "${GREEN}Signature metadata:${NC}"
cosign tree "$IMAGE" 2>/dev/null || echo "Use 'cosign tree $IMAGE' to view signatures"
