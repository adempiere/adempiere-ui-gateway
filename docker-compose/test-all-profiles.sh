#!/bin/bash
# =============================================================================
#  ADempiere UI Gateway — Profile Validation
#  Sequentially restarts with each profile and runs health-check.sh.
#  Reports a pass/fail summary at the end.
#
#  Usage: ./test-all-profiles.sh
#         Leaves the stack running with the "all" profile when done.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FULL_RESTART="$SCRIPT_DIR/full-restart-with-healthcheck.sh"

PROFILES=(vue zk auth cache report scheduler storage all)

declare -A RESULTS

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

for profile in "${PROFILES[@]}"; do
    echo ""
    log "════════════════════════════════════════════"
    log "  Profile: $profile"
    log "════════════════════════════════════════════"
    if bash "$FULL_RESTART" "$profile"; then
        RESULTS[$profile]="PASS"
    else
        RESULTS[$profile]="FAIL"
    fi
done

echo ""
log "════════════════════════════════════════════"
log "  Summary"
log "════════════════════════════════════════════"
FAIL_COUNT=0
for profile in "${PROFILES[@]}"; do
    result="${RESULTS[$profile]}"
    [ "$result" = "FAIL" ] && FAIL_COUNT=$((FAIL_COUNT + 1))
    printf "  %-12s %s\n" "$profile" "$result"
done
echo ""
[ "$FAIL_COUNT" -eq 0 ] && log "All profiles passed." && exit 0
log "$FAIL_COUNT profile(s) failed."
exit 1
