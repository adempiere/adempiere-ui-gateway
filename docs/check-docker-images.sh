#!/bin/bash
# File: check-docker-images.sh
# Purpose: Check Docker image versions used in adempiere-ui-gateway stack
# Location: adempiere-ui-gateway/docs/
#
# Checks images from three sources:
#   1. SHW Customizations (marcalwestf namespace on Docker Hub) - should NOT migrate
#   2. ADempiere Core (ghcr.io/adempiere namespace) - official ADempiere images
#   3. ADempiere Legacy (openls namespace on Docker Hub) - awaiting migration to ghcr.io
#
# Requirements:
#   - curl: HTTP client for fetching registry data
#   - jq: JSON parser for API responses
#
# Install:
#   Ubuntu/Debian: sudo apt install curl jq
#   Mac: brew install curl jq
#
# Authentication (optional, for GitHub Packages):
#   Pass GitHub token as argument or set GITHUB_TOKEN environment variable
#   Generate token at: https://github.com/settings/tokens (scope: read:packages)
#
# Usage:
#   ./check-docker-images.sh [GITHUB_TOKEN]
#   ./check-docker-images.sh
#   GITHUB_TOKEN="ghp_xxx" ./check-docker-images.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Path to env_template.env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../docker-compose/env_template.env"

# GitHub authentication (optional, for private packages)
GITHUB_TOKEN="${1:-${GITHUB_TOKEN:-}}"

# Check if env_template.env exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: env_template.env not found at $ENV_FILE${NC}"
    exit 1
fi

# Check if required tools are installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq is not installed. Install it for better JSON parsing.${NC}"
    echo "  Ubuntu/Debian: sudo apt install jq"
    echo "  Mac: brew install jq"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is required but not installed.${NC}"
    exit 1
fi

echo "========================================================================"
echo "ADempiere UI Gateway - Docker Image Version Check"
echo "========================================================================"
echo ""
echo "Configuration file: $ENV_FILE"
echo ""

# Function to extract image name and version from env file
get_current_image() {
    local var_name=$1
    local image=$(grep "^${var_name}=" "$ENV_FILE" | cut -d'"' -f2 | envsubst)
    echo "$image"
}

# Function to parse image into registry, namespace, name, and tag
parse_image() {
    local image=$1
    local registry=""
    local namespace=""
    local name=""
    local tag=""

    # Check if image has registry prefix
    if [[ "$image" =~ ^([^/]+\.[^/]+)/(.+):(.+)$ ]]; then
        # Has registry: ghcr.io/namespace/name:tag
        registry="${BASH_REMATCH[1]}"
        local rest="${BASH_REMATCH[2]}"
        tag="${BASH_REMATCH[3]}"

        if [[ "$rest" =~ ^([^/]+)/(.+)$ ]]; then
            namespace="${BASH_REMATCH[1]}"
            name="${BASH_REMATCH[2]}"
        else
            name="$rest"
        fi
    elif [[ "$image" =~ ^([^/]+)/([^:]+):(.+)$ ]]; then
        # Docker Hub: namespace/name:tag
        registry="docker.io"
        namespace="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"
        tag="${BASH_REMATCH[3]}"
    else
        echo "N/A|N/A|N/A|N/A"
        return
    fi

    echo "$registry|$namespace|$name|$tag"
}

# Function to get latest tag from Docker Hub
get_dockerhub_latest() {
    local namespace=$1
    local name=$2

    local url="https://hub.docker.com/v2/repositories/${namespace}/${name}/tags?page_size=100"
    local response=$(curl -s "$url" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$response" ]; then
        echo "N/A"
        return
    fi

    # Try to find the latest semantic version tag (not 'latest')
    local latest=$(echo "$response" | jq -r '.results[] | select(.name != "latest") | .name' 2>/dev/null | head -n1)

    if [ -z "$latest" ]; then
        echo "N/A"
    else
        echo "$latest"
    fi
}

# Function to get latest tag from GitHub Container Registry
get_ghcr_latest() {
    local namespace=$1
    local name=$2

    # Try to get versions from GitHub Packages API
    local api_url="https://api.github.com/orgs/${namespace}/packages/container/${name}/versions"

    local headers=""
    if [ -n "$GITHUB_TOKEN" ]; then
        headers="-H \"Authorization: Bearer $GITHUB_TOKEN\""
    fi

    local response=$(eval curl -s $headers "$api_url" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$response" ]; then
        echo "N/A"
        return
    fi

    # Extract the first tag that's not 'latest'
    local latest=$(echo "$response" | jq -r '.[0].metadata.container.tags[] | select(. != "latest")' 2>/dev/null | head -n1)

    if [ -z "$latest" ]; then
        echo "N/A"
    else
        echo "$latest"
    fi
}

# Function to determine image type and migration status
get_image_type() {
    local namespace=$1
    local registry=$2

    case "$namespace" in
        marcalwestf)
            echo -e "${CYAN}SHW Custom${NC}"
            ;;
        adempiere)
            if [ "$registry" == "ghcr.io" ]; then
                echo -e "${GREEN}ADempiere Core${NC}"
            else
                echo -e "${YELLOW}ADempiere Legacy${NC}"
            fi
            ;;
        openls)
            echo -e "${YELLOW}Legacy (migrate)${NC}"
            ;;
        *)
            echo -e "${BLUE}Other${NC}"
            ;;
    esac
}

# Function to get migration status icon
get_migration_status() {
    local registry=$1
    local namespace=$2

    if [ "$registry" == "ghcr.io" ] && [ "$namespace" == "adempiere" ]; then
        echo -e "${GREEN}✓${NC}"
    elif [ "$namespace" == "marcalwestf" ]; then
        echo -e "${CYAN}--${NC}"  # Not applicable (SHW customization)
    elif [ "$namespace" == "openls" ] || ([ "$registry" == "docker.io" ] && [ "$namespace" == "adempiere" ]); then
        echo -e "${RED}✗${NC}"  # Not migrated
    else
        echo -e "${BLUE}?${NC}"
    fi
}

# Array of image variables to check (ADempiere-related only)
IMAGES=(
    "S3_GATEWAY_RS_IMAGE:S3 Gateway"
    "ADEMPIERE_ZK_IMAGE:ZK UI (SHW)"
    "ADEMPIERE_PROCESSOR_IMAGE:Processors (SHW)"
    "DICTIONARY_RS_IMAGE:Dictionary Service"
    "VUE_BACKEND_GRPC_SERVER_IMAGE:gRPC Server (SHW)"
    "VUE_REPORT_GRPC_SERVER_IMAGE:Report Engine"
    "VUE_UI_IMAGE:Vue UI (SHW)"
    "ADEMPIERE_SITE_IMAGE:Landing Page"
)

echo "Checking images..."
echo ""

# Header
printf "%-30s %-15s %-25s %-20s %-15s %s\n" "Image" "Type" "Registry/Namespace" "Current" "Latest" "Status"
printf "%-30s %-15s %-25s %-20s %-15s %s\n" "------------------------------" "---------------" "-------------------------" "--------------------" "---------------" "------"

# Check each image
for img_entry in "${IMAGES[@]}"; do
    IFS=':' read -r var_name display_name <<< "$img_entry"

    current_image=$(get_current_image "$var_name")

    if [ -z "$current_image" ]; then
        printf "%-30s %-15s %-25s %-20s %-15s %s\n" "$display_name" "N/A" "N/A" "N/A" "N/A" "✗"
        continue
    fi

    IFS='|' read -r registry namespace name tag <<< "$(parse_image "$current_image")"

    if [ "$registry" == "N/A" ]; then
        printf "%-30s %-15s %-25s %-20s %-15s %s\n" "$display_name" "Parse Error" "$current_image" "N/A" "N/A" "✗"
        continue
    fi

    # Get latest version
    latest="N/A"
    if [ "$registry" == "docker.io" ]; then
        latest=$(get_dockerhub_latest "$namespace" "$name")
    elif [ "$registry" == "ghcr.io" ]; then
        latest=$(get_ghcr_latest "$namespace" "$name")
    fi

    # Format registry/namespace for display
    reg_display="${registry}/${namespace}"

    # Get image type
    img_type=$(get_image_type "$namespace" "$registry")

    # Get migration status
    mig_status=$(get_migration_status "$registry" "$namespace")

    # Compare versions
    version_status=""
    if [ "$tag" == "$latest" ] || [ "$latest" == "N/A" ]; then
        version_status=""
    else
        version_status=$(echo -e "${YELLOW}⚠${NC}")
    fi

    printf "%-30s %-31s %-25s %-20s %-15s %s %s\n" "$display_name" "$img_type" "$reg_display" "$tag" "$latest" "$mig_status" "$version_status"
done

echo ""
echo "========================================================================"
echo "Legend:"
echo ""
echo "Image Types:"
echo -e "  ${GREEN}ADempiere Core${NC}        - Official ADempiere services (on ghcr.io)"
echo -e "  ${CYAN}SHW Custom${NC}            - Systemhaus-Westfalia customizations (stay on Docker Hub)"
echo -e "  ${YELLOW}Legacy (migrate)${NC}      - Needs migration to ghcr.io/adempiere"
echo ""
echo "Migration Status:"
echo -e "  ${GREEN}✓${NC}   Migrated to ghcr.io/adempiere"
echo -e "  ${CYAN}--${NC}  Not applicable (SHW customization, stays on marcalwestf)"
echo -e "  ${RED}✗${NC}   Not migrated yet (should move to ghcr.io/adempiere)"
echo ""
echo "Version Status:"
echo -e "  ${YELLOW}⚠${NC}   Newer version available"
echo ""
echo "Image Categories:"
echo ""
echo "1. SHW Customizations (marcalwestf/* on Docker Hub):"
echo "   - adempiere-shw-zk"
echo "   - adempiere-processors-service"
echo "   - adempiere-grpc-server"
echo "   - adempiere-vue"
echo "   → Should REMAIN on Docker Hub (marcalwestf namespace)"
echo ""
echo "2. ADempiere Core Services (ghcr.io/adempiere/*):"
echo "   - s3-gateway-rs (✓ migrated)"
echo "   - adempiere-report-engine-service (✓ migrated)"
echo ""
echo "3. Awaiting Migration (openls/* → ghcr.io/adempiere/*):"
echo "   - dictionary-rs"
echo "   - adempiere-landing-page"
echo ""
echo "To update an image version:"
echo "  1. Edit: $ENV_FILE"
echo "  2. Find the _IMAGE variable"
echo "  3. Update the tag/version"
echo "  4. Restart stack: cd docker-compose && ./stop-all.sh && ./start-all.sh"
echo "========================================================================"
