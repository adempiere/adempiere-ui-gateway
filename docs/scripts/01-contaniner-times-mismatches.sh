#!/bin/bash
#
# Container Time Synchronization Checker
#
# Purpose: Verify all running Docker containers have synchronized time with host
# Only reports containers with time mismatches (> 2 second difference)
#
# Usage: ./01-contaniner-times-mismatches.sh
#
# Exit codes:
#   0 - All containers synchronized
#   1 - One or more containers have time mismatches
#   2 - Error executing script
#
# Date: 2026-02-13
# Project: ADempiere UI Gateway

# Note: NOT using 'set -e' here to ensure script continues even if a container errors
# We want to check ALL containers, even if some have issues

# Detect if output is to a terminal (enable colors) or redirected to file (disable colors)
if [ -t 1 ]; then
  # Output is to terminal - use colors
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  NC='\033[0m' # No Color
else
  # Output is redirected - no colors
  RED=''
  GREEN=''
  YELLOW=''
  NC=''
fi

# Tolerance in seconds (allow small differences due to command execution delay)
TOLERANCE=2

# Get host time as Unix timestamp
HOST_TIME=$(date +%s)
HOST_DATE=$(date)

echo "=========================================="
echo "Container Time Synchronization Check"
echo "=========================================="
echo ""
echo "Host Time: $HOST_DATE"
echo "Host Timestamp: $HOST_TIME"
echo "Tolerance: ±${TOLERANCE} seconds"
echo ""
echo "Checking running containers..."
echo ""

# Counter for mismatches
MISMATCH_COUNT=0
TOTAL_COUNT=0
ERRORS=0

# Capture container list FIRST to avoid process substitution issues with output redirection
CONTAINER_LIST=$(docker ps --format "{{.Names}}")

# Check all running containers
while IFS= read -r container; do
  TOTAL_COUNT=$((TOTAL_COUNT + 1))

  # Get container time - use explicit error handling
  CONTAINER_TIME=$(docker exec "$container" date +%s 2>/dev/null || echo "ERROR")

  if [ "$CONTAINER_TIME" = "ERROR" ]; then
    echo -e "${YELLOW}⚠️  WARNING: $container - Could not retrieve time${NC}" || true
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Calculate difference
  DIFF=$((CONTAINER_TIME - HOST_TIME))

  # Get absolute value
  ABS_DIFF=${DIFF#-}

  # Check if difference exceeds tolerance
  if [ "$ABS_DIFF" -gt "$TOLERANCE" ]; then
    CONTAINER_DATE=$(docker exec "$container" date 2>/dev/null || echo "ERROR")
    echo -e "${RED}❌ MISMATCH: $container${NC}" || true
    echo "   Host:      $HOST_DATE" || true
    echo "   Container: $CONTAINER_DATE" || true
    echo "   Difference: ${DIFF}s (${ABS_DIFF}s absolute)" || true
    echo "" || true
    MISMATCH_COUNT=$((MISMATCH_COUNT + 1))
  fi

done <<< "$CONTAINER_LIST"

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Total containers checked: $TOTAL_COUNT"
echo "Containers synchronized: $((TOTAL_COUNT - MISMATCH_COUNT - ERRORS))"
echo "Mismatches found: $MISMATCH_COUNT"
echo "Errors: $ERRORS"
echo ""

# Final status
if [ "$MISMATCH_COUNT" -eq 0 ] && [ "$ERRORS" -eq 0 ]; then
  echo -e "${GREEN}✅ SUCCESS: All containers synchronized with host time${NC}"
  exit 0
elif [ "$MISMATCH_COUNT" -eq 0 ] && [ "$ERRORS" -gt 0 ]; then
  echo -e "${YELLOW}⚠️  WARNING: No mismatches, but $ERRORS container(s) could not be checked${NC}"
  exit 0
else
  echo -e "${RED}❌ FAILED: $MISMATCH_COUNT container(s) have time mismatches${NC}"
  echo ""
  echo "Troubleshooting tips:"
  echo "  1. Check TZ environment variable: docker exec <container> printenv TZ"
  echo "  2. Check timezone mount: docker inspect <container> | grep -A 5 Mounts"
  echo "  3. Verify /etc/timezone exists: docker exec <container> cat /etc/timezone"
  echo "  4. Check system time sync: timedatectl status"
  exit 1
fi
