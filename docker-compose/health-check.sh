#!/bin/bash
# =============================================================================
#  ADempiere UI Gateway — Service Health Check
#  Usage: ./health-check.sh [profile]
#         Without profile: checks all containers that exist in Docker.
#         With profile:    checks only containers belonging to that profile.
# =============================================================================

# ── Colors & icons ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
OK="✅"; FAIL="❌"; WARN="⚠️ "; INFO="ℹ️ "
PASS_COUNT=0; FAIL_COUNT=0; WARN_COUNT=0

# ── Docker command (no sudo needed if user is in docker group) ────────────────
if docker ps &>/dev/null; then DOCKER="docker"; else DOCKER="sudo docker"; fi

# ── Load project name and ports from .env ────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"
P="${COMPOSE_PROJECT_NAME:-adempiere-ui-gateway}"

# ── Profile filter ────────────────────────────────────────────────────────────
# When a profile is given, build the set of container names that belong to it
# by querying docker compose. When omitted, all existing containers are checked.
PROFILE="${1:-}"
PROFILE_CONTAINERS=()
if [ -n "$PROFILE" ] && [ "$PROFILE" != "all" ]; then
    mapfile -t PROFILE_CONTAINERS < <(
        COMPOSE_PROFILES="$PROFILE" docker compose --project-directory "$SCRIPT_DIR" \
            -f "$SCRIPT_DIR/docker-compose.yml" config 2>/dev/null \
        | grep 'container_name:' | awk '{print $2}'
    )
fi

# Returns 0 if the container should be checked, 1 if it should be skipped.
in_profile() {
    [ "${#PROFILE_CONTAINERS[@]}" -eq 0 ] && return 0  # no filter: check all
    local c; for c in "${PROFILE_CONTAINERS[@]}"; do [ "$c" = "$1" ] && return 0; done
    return 1
}

# ── Helper: check container running/health status ─────────────────────────────
check_container() {
    local container=$1 label=$2
    in_profile "$container" || return 0
    local status health
    status=$($DOCKER inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
    if [ -z "$status" ]; then
        return 0  # container not in active profile — skip silently
    fi
    printf "  %-50s" "$label"
    health=$($DOCKER inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null)
    if [ "$status" = "running" ]; then
        case "$health" in
            healthy)   echo -e "${GREEN}${OK}  running · healthy${NC}";                ((PASS_COUNT++)) ;;
            unhealthy) echo -e "${RED}${FAIL}  running · unhealthy${NC}";              ((FAIL_COUNT++)) ;;
            starting)  echo -e "${YELLOW}${WARN}  running · healthcheck starting${NC}"; ((WARN_COUNT++)) ;;
            *)         echo -e "${GREEN}${OK}  running${NC}";                           ((PASS_COUNT++)) ;;
        esac
    else
        echo -e "${RED}${FAIL}  $status${NC}"; ((FAIL_COUNT++))
    fi
}

# ── Helper: check init container — exited cleanly is expected and OK ──────────
check_init_container() {
    local container=$1 label=$2
    in_profile "$container" || return 0
    local status
    status=$($DOCKER inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
    if [ -z "$status" ]; then
        return 0  # container not in active profile — skip silently
    fi
    printf "  %-50s" "$label"
    if [ "$status" = "exited" ]; then
        local exit_code
        exit_code=$($DOCKER inspect --format='{{.State.ExitCode}}' "$container" 2>/dev/null)
        if [ "$exit_code" = "0" ]; then
            echo -e "${GREEN}${OK}  exited cleanly (init container — expected)${NC}"; ((PASS_COUNT++))
        else
            echo -e "${RED}${FAIL}  exited with code $exit_code${NC}"; ((FAIL_COUNT++))
        fi
    elif [ "$status" = "running" ]; then
        echo -e "${GREEN}${OK}  running${NC}"; ((PASS_COUNT++))
    else
        echo -e "${RED}${FAIL}  $status${NC}"; ((FAIL_COUNT++))
    fi
}

# ── Helper: check HTTP endpoint (retries up to 3×, 10 s apart) ─────────────────
check_http() {
    local label=$1 url=$2 accepted="${3:-200}"
    printf "  %-50s" "$label"
    local code attempt retries=3 delay=10
    for attempt in $(seq 1 $retries); do
        code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)
        if echo "$accepted" | grep -qw "$code"; then
            echo -e "${GREEN}${OK}  HTTP $code  →  $url${NC}"; ((PASS_COUNT++))
            return
        fi
        [ "$attempt" -lt "$retries" ] && sleep "$delay"
    done
    echo -e "${RED}${FAIL}  HTTP $code  →  $url${NC}"; ((FAIL_COUNT++))
}

# ── Helper: get container's internal Docker network IP ────────────────────────
container_ip() {
    $DOCKER inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$1" 2>/dev/null
}

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  ADempiere UI Gateway — Service Health Check${NC}"
echo    "  Project : $P"
echo    "  Profile : ${PROFILE:-all}"
echo    "  Date    : $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"

# ── 1. Infrastructure ─────────────────────────────────────────────────────────
echo ""; echo -e "${BLUE}${BOLD}─── 1. Infrastructure ──────────────────────────────────────${NC}"
check_container "$P.postgresql"            "PostgreSQL"
check_container "$P.zookeeper"             "Zookeeper"
check_container "$P.kafka"                 "Kafka"
check_container "$P.opensearch"            "OpenSearch"
check_container "$P.s3-storage"            "MinIO S3 Storage"
check_init_container "$P.s3-client"        "MinIO S3 Client (init)"

# ── 2. Backend Services ───────────────────────────────────────────────────────
echo ""; echo -e "${BLUE}${BOLD}─── 2. Backend Services ────────────────────────────────────${NC}"
check_container "$P.vue-grpc-server"       "gRPC Server (adempiere-grpc-server)"
check_container "$P.report-engine"         "Report Engine"
check_container "$P.processor"             "ADempiere Processor"
check_container "$P.dictionary-rs"         "Dictionary RS"
check_container "$P.s3-gateway-rs"         "S3 Gateway RS"
check_container "$P.envoy-grpc-proxy"      "Envoy gRPC Proxy"
check_container "$P.keycloak-service"      "Keycloak"
check_container "$P.scheduler-dkron"       "Dkron Scheduler"

# ── 3. Frontend & Gateway ─────────────────────────────────────────────────────
echo ""; echo -e "${BLUE}${BOLD}─── 3. Frontend & Gateway ──────────────────────────────────${NC}"
check_container "$P.zk"                    "ADempiere ZK"
check_container "$P.vue-ui"                "Vue UI"
check_container "$P.site"                  "ADempiere Site"
check_container "$P.nginx-ui-gateway"      "Nginx UI Gateway"

# ── 4. Monitoring & Tooling ───────────────────────────────────────────────────
echo ""; echo -e "${BLUE}${BOLD}─── 4. Monitoring & Tooling ────────────────────────────────${NC}"
check_container "$P.kafdrop"               "Kafdrop (Kafka UI)"
check_container "$P.opensearch-dashboards" "OpenSearch Dashboards"
check_init_container "$P.opensearch-setup" "OpenSearch Setup (init)"

# ── 5. HTTP Endpoint Checks ───────────────────────────────────────────────────
echo ""; echo -e "${BLUE}${BOLD}─── 5. HTTP Endpoint Checks ────────────────────────────────${NC}"

# All HTTP checks use container IPs directly — no dependency on host port
# mappings or LAN IP, so the script works regardless of network location.

_http_by_container() {
    local label=$1 container=$2 port=$3 path="${4:-/}" accepted="${5:-200}" guard="${6:-$2}"
    # guard: container whose existence/profile membership gates this check.
    # Defaults to container (the one whose IP is used for the request).
    # Set guard to a backend container when the HTTP request goes via a proxy (e.g. nginx).
    in_profile "$guard" || return 0
    $DOCKER inspect "$guard" &>/dev/null || return 0  # not in active profile — skip
    local ip
    ip=$(container_ip "$container")
    if [ -n "$ip" ]; then
        check_http "$label" "http://${ip}:${port}${path}" "$accepted"
    else
        printf "  %-50s" "$label"
        echo -e "${YELLOW}${WARN}  could not resolve container IP${NC}"; ((WARN_COUNT++))
    fi
}

NGINX_PORT="${NGINX_UI_GATEWAY_INTERNAL_PORT:-80}"
KAFDROP_PORT="${KAFDROP_PORT:-9000}"
OSDASH_PORT="${OPENSEARCH_DASHBOARDS_PORT:-5601}"
KEYCLOAK_PORT="${KEYCLOAK_PORT:-8080}"
DKRON_PORT="${DKRON_UI_PORT:-8080}"
MINIO_PORT="${S3_CONSOLE_PORT:-9090}"
DICT_PORT="${DICTIONARY_RS_PORT:-7878}"
OS_PORT="${OPENSEARCH_PORT:-9200}"

_http_by_container "Nginx (root)"                "$P.nginx-ui-gateway"      $NGINX_PORT   "/"        "200 301 302" "$P.site"
_http_by_container "Vue UI  (via nginx /vue)"    "$P.nginx-ui-gateway"      $NGINX_PORT   "/vue"     "200"         "$P.vue-ui"
_http_by_container "ZK UI   (via nginx /webui)"  "$P.nginx-ui-gateway"      $NGINX_PORT   "/webui"   "200 301 302" "$P.zk"
_http_by_container "Kafdrop"                     "$P.kafdrop"               $KAFDROP_PORT "/"        "200"
_http_by_container "OpenSearch Dashboards"       "$P.opensearch-dashboards" $OSDASH_PORT  "/"        "200 301 302"
_http_by_container "Keycloak"                    "$P.keycloak-service"      $KEYCLOAK_PORT "/"       "200 301 302"
_http_by_container "Dkron UI"                    "$P.scheduler-dkron"       $DKRON_PORT   "/ui"      "200 301 302"
_http_by_container "MinIO S3 Console"            "$P.s3-storage"            $MINIO_PORT   "/"        "200 301 302"
_http_by_container "Dictionary RS"               "$P.dictionary-rs"         $DICT_PORT    "/"        "200"
_http_by_container "OpenSearch"                  "$P.opensearch"            $OS_PORT      "/"        "200 401"

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}${OK}  Passed  : ${PASS_COUNT}${NC}"
echo -e "  ${RED}${FAIL}  Failed  : ${FAIL_COUNT}${NC}"
echo -e "  ${YELLOW}${WARN}  Warnings: ${WARN_COUNT}${NC}"
echo    "  ─────────────────────"
echo    "  Total   : ${TOTAL}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""
[ "$FAIL_COUNT" -gt 0 ] && exit 1 || exit 0
