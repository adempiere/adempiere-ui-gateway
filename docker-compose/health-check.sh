#!/bin/bash
# =============================================================================
#  ADempiere UI Gateway — Service Health Check
#  Usage: ./health-check.sh
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

# ── Helper: check container running/health status ─────────────────────────────
check_container() {
    local container=$1 label=$2
    printf "  %-50s" "$label"
    local status health
    status=$($DOCKER inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
    if [ -z "$status" ]; then
        echo -e "${RED}${FAIL}  container not found${NC}"; ((FAIL_COUNT++)); return 1
    fi
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
    printf "  %-50s" "$label"
    local status
    status=$($DOCKER inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
    if [ -z "$status" ]; then
        echo -e "${RED}${FAIL}  container not found${NC}"; ((FAIL_COUNT++)); return 1
    fi
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

# ── Helper: check HTTP endpoint ───────────────────────────────────────────────
check_http() {
    local label=$1 url=$2 accepted="${3:-200}"
    printf "  %-50s" "$label"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)
    if echo "$accepted" | grep -qw "$code"; then
        echo -e "${GREEN}${OK}  HTTP $code  →  $url${NC}"; ((PASS_COUNT++))
    else
        echo -e "${RED}${FAIL}  HTTP $code  →  $url${NC}";  ((FAIL_COUNT++))
    fi
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
    local label=$1 container=$2 port=$3 path="${4:-/}" accepted="${5:-200}"
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

_http_by_container "Nginx (root)"                "$P.nginx-ui-gateway"      $NGINX_PORT   "/"        "200 301 302"
_http_by_container "Vue UI  (via nginx /vue)"    "$P.nginx-ui-gateway"      $NGINX_PORT   "/vue"     "200"
_http_by_container "ZK UI   (via nginx /webui)"  "$P.nginx-ui-gateway"      $NGINX_PORT   "/webui"   "200 301 302"
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
