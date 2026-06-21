#!/bin/bash
#
# Simple Container Time Display
#
# Purpose: Display host time and all container times in a simple, readable format
# Useful for quick visual inspection of time synchronization
#
# Usage: ./03-all-container-times-simple.sh
#        ./03-all-container-times-simple.sh > Results/03-all-times.txt
#
# Date: 2026-02-13
# Project: ADempiere UI Gateway

# Note: NOT using 'set -e' here to ensure script continues even if a container errors
# We want to see ALL containers, even if some have issues

# Detect if output is to a terminal (enable colors) or redirected to file (disable colors)
if [ -t 1 ]; then
  # Output is to terminal - use colors
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  GREEN='\033[0;32m'
  BOLD='\033[1m'
  NC='\033[0m' # No Color
else
  # Output is redirected - no colors
  BLUE=''
  CYAN=''
  GREEN=''
  BOLD=''
  NC=''
fi

echo "=========================================="
echo "Container Time Display - Simple View"
echo "=========================================="
echo ""

# Host information
echo -e "${BOLD}${BLUE}HOST TIME:${NC}"
echo "  $(date)"
echo "  Timezone: $(cat /etc/timezone 2>/dev/null || echo 'N/A')"
echo "  Timestamp: $(date +%s)"
echo ""
echo "=========================================="
echo ""

# Container counter
COUNTER=0

# Check all running containers
echo -e "${BOLD}CONTAINER TIMES:${NC}"
echo ""

# Format: Container Name | Date/Time | TZ Variable
printf "%-45s | %-35s | %-25s\n" "CONTAINER NAME" "DATE & TIME" "TZ VARIABLE"
echo "----------------------------------------------|-------------------------------------|---------------------------"

# Capture container list FIRST to avoid process substitution issues with output redirection
CONTAINER_LIST=$(docker ps --format "{{.Names}}" | sort)

# Iterate over the captured list
while IFS= read -r container; do
  COUNTER=$((COUNTER + 1))

  # Get container date - use explicit error handling
  CONTAINER_DATE=$(docker exec "$container" date 2>/dev/null || echo "ERROR")
  if [ "$CONTAINER_DATE" = "ERROR" ]; then
    CONTAINER_DATE="ERROR: Could not retrieve"
  fi

  # Get TZ environment variable - use explicit error handling
  CONTAINER_TZ=$(docker exec "$container" printenv TZ 2>/dev/null || echo "")
  if [ -z "$CONTAINER_TZ" ]; then
    CONTAINER_TZ="(not set)"
  fi

  # Print formatted output - always continue regardless of errors
  printf "%-45s | %-35s | %-25s\n" "$container" "$CONTAINER_DATE" "$CONTAINER_TZ" || true

done <<< "$CONTAINER_LIST"

echo ""
echo "=========================================="
echo "Total containers: $COUNTER"
echo "=========================================="
echo ""
echo "Note: Compare all container times with host time above."
echo "      Times should match (accounting for timezone differences)."
echo "      If TZ variable shows '(not set)', container uses UTC by default."
