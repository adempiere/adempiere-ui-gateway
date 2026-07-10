#!/usr/bin/env bash
#
# Re-apply PostgreSQL role passwords from the environment on EVERY container start.
#
# Why: Postgres only applies POSTGRES_PASSWORD / creates roles during the initial initdb
# (empty data directory). On an already-initialised database the env vars are ignored, so
# editing them and restarting the stack would NOT change the credentials. This script closes
# that gap: it runs on every start and re-applies the passwords, making the documented
# "edit env + stop-all + start-all" flow actually work.
#
# It connects over the local unix socket (pg_hba `local all all trust`, the same way
# initdb.sh connects), so it needs no existing password — avoiding the chicken-and-egg of a
# TCP client that would require the OLD password to set a new one.
#
# ALTER ROLE is idempotent, so running this on an unchanged password is a no-op.

set -uo pipefail

PG_ADMIN="${POSTGRES_USER:-postgres}"
SOCKET_DIR="/var/run/postgresql"

log() { echo "[sync-credentials] $*"; }

# Wait until Postgres accepts local connections (bounded, so a broken DB never hangs start-up).
wait_ready() {
    local waited=0 timeout=180
    until pg_isready -U "$PG_ADMIN" -h "$SOCKET_DIR" -q; do
        if [ "$waited" -ge "$timeout" ]; then
            log "Postgres did not become ready within ${timeout}s; skipping credential sync."
            return 1
        fi
        sleep 2
        waited=$((waited + 2))
    done
    return 0
}

# apply <role> <password> — re-apply the password only if the role already exists and the
# password value is non-empty. Runs as the postgres superuser over the local socket.
# psql interpolates :"role" as a quoted identifier and :'pw' as a quoted literal, so
# passwords with special characters are handled safely.
apply() {
    local role="$1" pw="$2"
    [ -z "$pw" ] && { log "No password provided for role '$role'; skipping."; return 0; }

    local exists
    exists=$(psql -U "$PG_ADMIN" -d postgres -tAc \
        "SELECT 1 FROM pg_roles WHERE rolname = '${role}'" 2>/dev/null)
    if [ "$exists" != "1" ]; then
        log "Role '$role' does not exist yet; skipping (will be created by initdb)."
        return 0
    fi

    if psql -v ON_ERROR_STOP=1 -U "$PG_ADMIN" -d postgres \
            -v role="$role" -v pw="$pw" >/dev/null 2>&1 <<'SQL'
ALTER ROLE :"role" WITH PASSWORD :'pw';
SQL
    then
        log "Password re-applied for role '$role'."
    else
        log "WARNING: could not re-apply password for role '$role'."
    fi
}

main() {
    wait_ready || return 0
    apply "$PG_ADMIN" "${POSTGRES_PASSWORD:-}"
    apply "adempiere" "${ADEMPIERE_DB_PASSWORD:-}"
    log "Credential sync finished."
}

main
