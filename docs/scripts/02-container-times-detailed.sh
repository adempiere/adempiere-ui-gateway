#!/bin/bash
#
# Container Time and Timezone Detailed Report
#
# Purpose: Display detailed time and timezone configuration for host and all containers
# Useful for diagnosing timezone configuration issues
#
# Usage: ./02-container-times-detailed.sh
#        ./02-container-times-detailed.sh | less  # For easier reading
#
# Date: 2026-02-13
# Project: ADempiere UI Gateway

# Note: NOT using 'set -e' here to ensure script continues even if a container errors
# We want to check ALL containers, even if some have issues

# Detect if output is to a terminal (enable colors) or redirected to file (disable colors)
if [ -t 1 ]; then
  # Output is to terminal - use colors
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  BOLD='\033[1m'
  NC='\033[0m' # No Color
else
  # Output is redirected - no colors
  BLUE=''
  CYAN=''
  GREEN=''
  YELLOW=''
  RED=''
  BOLD=''
  NC=''
fi

echo "=========================================="
echo "Container Time & Timezone Detailed Report"
echo "=========================================="
echo ""

# Host information
echo -e "${BOLD}${BLUE}HOST:${NC}"
echo -e "  ${CYAN}Date:${NC}            $(date)"
echo -e "  ${CYAN}Timestamp:${NC}       $(date +%s)"
echo -e "  ${CYAN}Timezone:${NC}        $(cat /etc/timezone 2>/dev/null || echo 'N/A')"
echo -e "  ${CYAN}TZ variable:${NC}     ${TZ:-'not set'}"
echo -e "  ${CYAN}timedatectl:${NC}"
timedatectl 2>/dev/null | sed 's/^/    /' || echo "    N/A (systemd not available)"
echo ""
echo "=========================================="
echo ""

# Container counter
CONTAINER_COUNT=0

# Capture container list FIRST to avoid process substitution issues with output redirection
CONTAINER_LIST=$(docker ps --format "{{.Names}}")

# Check all running containers
while IFS= read -r container; do
  CONTAINER_COUNT=$((CONTAINER_COUNT + 1))

  echo -e "${BOLD}${GREEN}[$CONTAINER_COUNT] $container${NC}" || true

  # Get container date - use explicit error handling
  CONTAINER_DATE=$(docker exec "$container" date 2>/dev/null || echo "ERROR")
  if [ "$CONTAINER_DATE" != "ERROR" ]; then
    echo -e "  ${CYAN}Date:${NC}            $CONTAINER_DATE" || true
  else
    echo -e "  ${CYAN}Date:${NC}            ${RED}ERROR: Could not retrieve${NC}" || true
  fi

  # Get container timestamp - use explicit error handling
  CONTAINER_TIMESTAMP=$(docker exec "$container" date +%s 2>/dev/null || echo "ERROR")
  if [ "$CONTAINER_TIMESTAMP" != "ERROR" ]; then
    echo -e "  ${CYAN}Timestamp:${NC}       $CONTAINER_TIMESTAMP" || true

    # Calculate difference from host
    HOST_TIME=$(date +%s)
    DIFF=$((CONTAINER_TIMESTAMP - HOST_TIME))
    if [ "${DIFF#-}" -gt 2 ]; then
      echo -e "  ${CYAN}Time diff:${NC}       ${RED}${DIFF}s (MISMATCH!)${NC}" || true
    else
      echo -e "  ${CYAN}Time diff:${NC}       ${GREEN}${DIFF}s (OK)${NC}" || true
    fi
  else
    echo -e "  ${CYAN}Timestamp:${NC}       ${RED}ERROR${NC}" || true
  fi

  # Get TZ environment variable - use explicit error handling
  CONTAINER_TZ=$(docker exec "$container" printenv TZ 2>/dev/null || echo "")
  if [ -n "$CONTAINER_TZ" ]; then
    echo -e "  ${CYAN}TZ env var:${NC}      $CONTAINER_TZ" || true
  else
    echo -e "  ${CYAN}TZ env var:${NC}      ${YELLOW}not set${NC}" || true
  fi

  # Get /etc/timezone content - use explicit error handling
  CONTAINER_TIMEZONE=$(docker exec "$container" cat /etc/timezone 2>/dev/null || echo "ERROR")
  if [ "$CONTAINER_TIMEZONE" != "ERROR" ]; then
    echo -e "  ${CYAN}/etc/timezone:${NC}   $CONTAINER_TIMEZONE" || true
  else
    echo -e "  ${CYAN}/etc/timezone:${NC}   ${YELLOW}not mounted or not readable${NC}" || true
  fi

  # Get /etc/localtime info - use explicit error handling
  LOCALTIME_INFO=$(docker exec "$container" ls -l /etc/localtime 2>/dev/null || echo "ERROR")
  if [ "$LOCALTIME_INFO" != "ERROR" ]; then
    echo -e "  ${CYAN}/etc/localtime:${NC}  $(echo $LOCALTIME_INFO | awk '{print $NF}')" || true
  else
    echo -e "  ${CYAN}/etc/localtime:${NC}  ${YELLOW}not mounted${NC}" || true
  fi

  # Check timezone mounts from docker inspect - use explicit error handling
  MOUNTS=$(docker inspect "$container" 2>/dev/null | grep -A 2 '"Source".*timezone\|"Source".*localtime' | grep -E 'Source|Destination' | tr -d ' ",' | paste -d ' ' - - || echo "")
  if [ -n "$MOUNTS" ]; then
    echo -e "  ${CYAN}Volume mounts:${NC}" || true
    echo "$MOUNTS" | while IFS= read -r line; do
      echo "    $line" || true
    done
  fi

  echo "" || true

done <<< "$CONTAINER_LIST"

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Total containers checked: $CONTAINER_COUNT"
echo ""
echo "Legend:"
echo "  - TZ env var: Runtime timezone setting (preferred method)"
echo "  - /etc/timezone: System timezone file (static)"
echo "  - /etc/localtime: System localtime symlink (binary)"
echo ""
echo "Recommendations:"
echo "  1. All containers should have TZ environment variable set"
echo "  2. Time difference should be < 2 seconds from host"
echo "  3. Timezone configuration should be consistent across all containers"
