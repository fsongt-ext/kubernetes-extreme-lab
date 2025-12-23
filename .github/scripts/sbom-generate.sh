#!/usr/bin/env bash

##############################################################################
# SBOM Generation Script
#
# Generates Software Bill of Materials (SBOM) using Syft
# Supports multiple formats: spdx-json, cyclonedx-json, syft-json
#
# Usage:
#   ./sbom-generate.sh <image> <output-format> <output-file>
#
# Example:
#   ./sbom-generate.sh myapp:latest spdx-json sbom.spdx.json
##############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script variables
IMAGE="${1:-}"
FORMAT="${2:-spdx-json}"
OUTPUT_FILE="${3:-sbom.json}"

# Validate inputs
if [ -z "$IMAGE" ]; then
  echo -e "${RED}Error: Image name is required${NC}"
  echo "Usage: $0 <image> [format] [output-file]"
  exit 1
fi

# Supported formats
SUPPORTED_FORMATS=("spdx-json" "cyclonedx-json" "syft-json" "table")

if [[ ! " ${SUPPORTED_FORMATS[@]} " =~ " ${FORMAT} " ]]; then
  echo -e "${YELLOW}Warning: Format '$FORMAT' may not be supported${NC}"
fi

echo -e "${GREEN}Generating SBOM for image: $IMAGE${NC}"
echo "Format: $FORMAT"
echo "Output: $OUTPUT_FILE"
echo ""

# Check if Syft is installed
if ! command -v syft &> /dev/null; then
  echo -e "${YELLOW}Syft not found. Installing...${NC}"
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
fi

# Generate SBOM
echo -e "${GREEN}Running Syft...${NC}"
syft "$IMAGE" \
  --output "$FORMAT=$OUTPUT_FILE" \
  --quiet

if [ $? -eq 0 ]; then
  echo -e "${GREEN}SBOM generated successfully!${NC}"
  echo "File: $OUTPUT_FILE"

  # Show file size
  if [ -f "$OUTPUT_FILE" ]; then
    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo "Size: $FILE_SIZE"

    # Show component count for JSON formats
    if [[ "$FORMAT" == *"json"* ]]; then
      if command -v jq &> /dev/null; then
        COMPONENT_COUNT=$(jq '[.artifacts // .components // .packages] | length' "$OUTPUT_FILE" 2>/dev/null || echo "N/A")
        echo "Components: $COMPONENT_COUNT"
      fi
    fi
  fi
else
  echo -e "${RED}Failed to generate SBOM${NC}"
  exit 1
fi
