#!/bin/bash
# =============================================================================
#  ADempiere UI Gateway — Full Restart + Health Check
#
#  Sequence: stop all services -> wait until stopped -> start all services
#  -> wait until running -> wait until healthchecks complete -> run health-check.sh
#
#  Usage: ./full-restart-with-healthcheck.sh [profile]
#         profile defaults to "all" if not specified
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Configuration ──────────────────────────────────────────────────────────
STOP_SCRIPT="$SCRIPT_DIR/stop-all.sh"
START_SCRIPT="$SCRIPT_DIR/start-all.sh"
HEALTH_CHECK_SCRIPT="$SCRIPT_DIR/health-check.sh"

PROJECT_NAME="adempiere-ui-gateway"   # COMPOSE_PROJECT_NAME fallback
PROFILE="${1:-all}"                   # Docker Compose profile (default: all)

STOP_TIMEOUT=120     # seconds to wait for all containers to disappear
START_TIMEOUT=600    # seconds to wait for all containers to reach "running"
POLL_INTERVAL=5      # seconds between polls

# RUNNING_CONTAINERS is populated dynamically after start-all.sh runs.
# Init containers (restart policy "no") are excluded automatically.
RUNNING_CONTAINERS=()

# Sudo detection: use sudo for docker and for calling child scripts if not already root
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
if $SUDO docker ps &>/dev/null; then DOCKER="$SUDO docker"; else DOCKER="docker"; fi

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

require_file() {
    local path=$1 label=$2
    if [ ! -f "$path" ]; then
        log "ERROR: $label not found at '$path'. Aborting."
        exit 1
    fi
}

wait_for_stop() {
    log "Waiting for all '$PROJECT_NAME.*' containers to stop (timeout ${STOP_TIMEOUT}s)..."
    local elapsed=0
    while true; do
        local running
        running=$($DOCKER ps --format '{{.Names}}' | grep -c "^${PROJECT_NAME}\." || true)
        if [ "$running" -eq 0 ]; then
            log "All containers stopped."
            return 0
        fi
        if [ "$elapsed" -ge "$STOP_TIMEOUT" ]; then
            log "WARNING: Timeout waiting for containers to stop ($running still running). Proceeding anyway."
            return 1
        fi
        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done
}

wait_for_start() {
    log "Waiting for all expected containers to be running (timeout ${START_TIMEOUT}s)..."
    local elapsed=0
    while true; do
        local not_running=0
        for container in "${RUNNING_CONTAINERS[@]}"; do
            local status
            status=$($DOCKER inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
            [ "$status" != "running" ] && not_running=$((not_running + 1))
        done
        if [ "$not_running" -eq 0 ]; then
            log "All expected containers are running."
            return 0
        fi
        if [ "$elapsed" -ge "$START_TIMEOUT" ]; then
            log "WARNING: Timeout waiting for containers to start ($not_running of ${#RUNNING_CONTAINERS[@]} not yet running). Proceeding to health check anyway."
            return 1
        fi
        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done
}

wait_for_healthy() {
    log "Waiting for container healthchecks to finish starting (timeout ${START_TIMEOUT}s)..."
    local elapsed=0
    while true; do
        local still_starting=0
        for container in "${RUNNING_CONTAINERS[@]}"; do
            local health
            health=$($DOCKER inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$container" 2>/dev/null)
            [ "$health" = "starting" ] && still_starting=$((still_starting + 1))
        done
        if [ "$still_starting" -eq 0 ]; then
            log "All container healthchecks have completed."
            return 0
        fi
        log "  ($still_starting container(s) still initializing...)"
        if [ "$elapsed" -ge "$START_TIMEOUT" ]; then
            log "WARNING: Timeout waiting for healthchecks ($still_starting still starting). Proceeding anyway."
            return 1
        fi
        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done
}

require_file "$STOP_SCRIPT" "Stop script"
require_file "$START_SCRIPT" "Start script"
require_file "$HEALTH_CHECK_SCRIPT" "Health check script"

log "=== Step 1/6: Stopping all services ==="
running_count=$($DOCKER ps --format '{{.Names}}' | grep -c "^${PROJECT_NAME}\." || true)
if [ "$running_count" -gt 0 ]; then
    log "Found $running_count running container(s). Calling stop script..."
    if ! $SUDO bash "$STOP_SCRIPT"; then
        log "ERROR: Stop script exited with a non-zero status. Aborting."
        exit 1
    fi
    log "=== Step 2/6: Waiting for shutdown ==="
    wait_for_stop
else
    log "No '$PROJECT_NAME' containers are running. Skipping stop."
fi

log "=== Step 3/6: Starting all services (profile: $PROFILE) ==="
if ! $SUDO bash "$START_SCRIPT" "$PROFILE"; then
    log "ERROR: Start script exited with a non-zero status. Aborting."
    exit 1
fi

# Discover which containers were actually started by this profile.
# Services without a restart directive have restart policy "no" — those are
# one-shot init containers (e.g. s3-client, opensearch-setup) and are excluded.
mapfile -t RUNNING_CONTAINERS < <(
    $DOCKER ps -a --format '{{.Names}}' 2>/dev/null \
    | grep "^${PROJECT_NAME}\." \
    | while read -r name; do
        policy=$($DOCKER inspect --format='{{.HostConfig.RestartPolicy.Name}}' "$name" 2>/dev/null)
        [ -n "$policy" ] && [ "$policy" != "no" ] && echo "$name"
      done \
    | sort
)
log "Monitoring ${#RUNNING_CONTAINERS[@]} long-running container(s)."

log "=== Step 4/6: Waiting for startup ==="
wait_for_start

log "=== Step 5/6: Waiting for healthchecks to complete ==="
wait_for_healthy

log "=== Step 6/6: Running health check ==="
bash "$HEALTH_CHECK_SCRIPT" "$PROFILE"
exit $?
