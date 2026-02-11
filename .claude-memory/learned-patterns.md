# Learned Patterns

Best practices, tips, and patterns discovered while working with ADempiere UI Gateway stack.

## Format
```
### Pattern: [Name]
**Context:**
- When this applies

**Approach:**
- How to do it

**Example:**
- Code/file reference

**Date learned:** YYYY-MM-DD
```

---

## Claude Code Workflow Patterns

### Session Startup: Always Check Team Memory
**Context:**
- Claude Code sessions are local and don't persist conversation history across sessions
- Team members work on different machines and need shared context
- `.claude-memory/` directory is version-controlled shared memory for the team

**Approach:**
At the START of EVERY session, Claude should:
1. Check if `.claude-memory/` directory exists in the project root
2. Read ALL files in it, especially:
   - `recent-work.md` - last changes and current context
   - `known-issues.md` - bugs and workarounds
   - `learned-patterns.md` - best practices
3. Use this context to understand what was done before
4. Continue work with full awareness of previous sessions

**Why This Matters:**
- Prevents repeating mistakes already solved
- Avoids breaking things that were recently fixed
- Maintains continuity across sessions and team members
- Leverages institutional knowledge

**Example:**
User asks: "What was the last plan executed?"
Without reading memory: "I don't have any previous context"
After reading memory: "The last plan was the branch migration from feature/SHW_General to adempiere-trunk on 2026-02-10, which updated 18+ service versions..."

**Implementation:**
- Claude's personal `MEMORY.md` should include this as standard startup protocol
- After reading, Claude can immediately provide context-aware assistance

**Date learned:** 2026-02-10

---

## gRPC & Envoy Proxy Patterns

### Adding New gRPC Services for Transcoding
**Context:**
- ADempiere uses Envoy proxy for gRPC-to-JSON transcoding
- When new services are added to the gRPC server, Envoy needs updated proto descriptors
- Easy to miss updating docker-compose volume mounts, causing startup failures

**Approach - The Three-Step Checklist:**
When adding new gRPC services, you MUST update all three:

1. **Proto Descriptor File** (`.dsc` or `.pb`)
   - Regenerate from source `.proto` files using `protoc`
   - Must include ALL service definitions (old + new)
   - File location: `docker-compose/envoy/definitions/adempiere-grpc-server.dsc`

2. **envoy.yaml Configuration**
   - Add new services to the transcoding services list
   - Update `proto_descriptor` path if filename changed
   - File location: `docker-compose/envoy/envoy.yaml`

3. **Docker-Compose Volume Mounts** ⚠️ **EASY TO FORGET!**
   - Update ALL docker-compose files that define grpc-proxy
   - Mount the descriptor file into container's `/data/` directory
   - Files to update:
     - `10c-grpc_proxy_service_standard.yml`
     - `docker-compose-standard.yml`
     - `docker-compose-auth.yml`
     - Any other compose files with grpc-proxy

**Example:**
```yaml
# In docker-compose grpc-proxy volumes:
volumes:
  - ./envoy/envoy.yaml:/etc/envoy/envoy.yaml:ro
  - ./envoy/definitions/adempiere-grpc-server.dsc:/data/adempiere-grpc-server.dsc:ro
  - ./envoy/definitions/adempiere-report-engine-service.dsc:/data/adempiere-report-engine-service.dsc:ro
```

```yaml
# In envoy.yaml:
typed_config:
  "@type": type.googleapis.com/envoy.extensions.filters.http.grpc_json_transcoder.v3.GrpcJsonTranscoder
  proto_descriptor: "/data/adempiere-grpc-server.dsc"
  services:
    - form.out_bound_order.OutBoundOrderService
    - form.payment_allocation.PaymentAllocation
```

**Verification:**
```bash
# Check descriptor contains service:
grep -a "ServiceName" docker-compose/envoy/definitions/adempiere-grpc-server.dsc

# Verify mount in docker-compose:
grep "adempiere-grpc-server" docker-compose/10c-grpc_proxy_service_standard.yml

# Test envoy startup:
docker logs adempiere-ui-gateway.envoy.grpc.proxy
```

**Date learned:** 2026-02-10 (learned the hard way!)

---

## Docker Compose Patterns

### Modular Service Composition
**Context:**
- Need different service combinations for different purposes (develop, production, testing)
- Want to avoid duplicating service definitions across multiple docker-compose files

**Approach:**
- Define each service in separate file: `##[a-z]-<service>_service_<variant>.yml`
- Number prefix controls assembly order (01, 02, ... 17, 18, etc.)
- Letter suffix for variants (a=with ports, b=without ports, c=develop, d=standard, etc.)
- Use bash arrays in start-all.sh to define service combinations per mode
- Script concatenates selected service files into docker-compose.yml

**Example:**
- AUTH_array uses `01b-postgres_service_without_ports.yml`
- DEVELOP_array uses `01a-postgres_service_with_ports.yml`
- See start-all.sh lines 88-176 for array definitions

**Date learned:** 2026-02-08

---

### Environment Variable Configuration Pattern
**Context:**
- Multiple containers need consistent configuration
- Want single source of truth for versions, ports, hostnames
- Both env_template.env and .env are committed to git for this infrastructure project

**Approach:**
- Use `env_template.env` as template with detailed comments/documentation
- `.env` is the active configuration file used by Docker Compose
- start-all.sh copies env_template.env to `.env` automatically
- Docker Compose substitutes variables at runtime

**CRITICAL: Two-File Workflow - Always Edit Template First**
1. **env_template.env** = Template with documentation (committed to git, with detailed comments)
2. **.env** = Active configuration (ALSO committed to git, synced from template)

**Best Practice Workflow:**
```bash
# 1. ALWAYS edit env_template.env FIRST (add variable with comments)
nano docker-compose/env_template.env

# 2. Copy changes to .env to keep them in sync
cp docker-compose/env_template.env docker-compose/.env
# OR let start-all.sh do it automatically

# 3. Test with the active .env
cd docker-compose/ && ./start-all.sh

# 4. Commit BOTH files together
git add docker-compose/env_template.env docker-compose/.env
git commit -m "Add new environment variable: OTHER_EXTERNAL_NETWORK"
```

**Why This Matters:**
- env_template.env serves as documentation for all team members (with detailed comments)
- .env is the active file that Docker Compose actually uses
- Both are version-controlled for infrastructure consistency
- Prevents configuration drift between template and active config
- Ensures all deployments use the same baseline configuration

**Example:**
```bash
# In env_template.env (with documentation):
CLIENT_NAME="adempiere-ui"
COMPOSE_PROJECT_NAME=${CLIENT_NAME}-gateway
POSTGRES_CONTAINER_NAME=${COMPOSE_PROJECT_NAME}.postgresql

# Optional External Network Configuration
# This allows ADempiere containers to connect to an EXTERNAL Docker network
OTHER_EXTERNAL_NETWORK="${ADEMPIERE_NETWORK}"
```

**Date learned:** 2026-02-08, **Enhanced:** 2026-02-11

---

## Database Patterns

### Persistent Database with Mounted Volume
**Context:**
- Need database to survive container deletion
- Want database accessible from host for backup/restore

**Approach:**
- Mount host directory to container's data directory
- Create directory structure: `postgresql/postgres_database/` (for data), `postgresql/postgres_backups/` (for seeds)
- Use Docker volumes defined in docker-compose service files
- Database persists even after `docker compose down`

**Example:**
```yaml
volumes:
  - ${POSTGRES_DB_PATH_ON_HOST}:${POSTGRES_DEFAULT_DB_PATH_ON_CONTAINER}
```
Where POSTGRES_DB_PATH_ON_HOST=`./postgresql/postgres_database`

**Date learned:** 2026-02-08

---

### Automatic Database Initialization
**Context:**
- First-time deployment needs database restore
- Want automated setup without manual steps

**Approach:**
- Use custom Dockerfile that copies initdb.sh into container
- initdb.sh runs automatically on first start (when DB doesn't exist)
- Checks for seed file, downloads from GitHub if not present
- Creates user, database, and restores from seed

**Example:**
See `postgresql/postgres.Dockerfile` and `postgresql/initdb.sh`
Check for seed: `POSTGRES_RESTORE_FILE_NAME=seed.backup`

**Date learned:** 2026-02-08

---

## nginx API Gateway Patterns

### Reverse Proxy as Single Entry Point
**Context:**
- Multiple backend services (ZK UI, Vue UI, gRPC, monitoring tools)
- Want single domain/port for external access

**Approach:**
- nginx listens on port 80 (only exposed port)
- Route by path: `/webui` → ZK, `/vue` → Vue, `/api` → gRPC proxy
- Use nginx upstreams pointing to container hostnames
- Configure long timeouts for ADempiere operations (900s = 15 minutes)

**Example:**
```nginx
proxy_read_timeout 900;
proxy_connect_timeout 900;
include /etc/nginx/api_gateway.conf;
```

**Date learned:** 2026-02-08

---

### gRPC Transcoding with Envoy
**Context:**
- ADempiere backend is gRPC
- Need RESTful HTTP API for easier client access

**Approach:**
- Use Envoy proxy as transcoding layer (grpc-proxy service)
- Maps HTTP REST calls to gRPC backends
- Path `/api/` routes through envoy transcoder
- Returns JSON responses from gRPC

**Example:**
Request: `curl http://api.adempiere.io/api/security/services`
Routes through: nginx → envoy → adempiere-grpc-server

**Date learned:** 2026-02-08

---

## Stack Management Patterns

### Service Startup Order
**Context:**
- Services have dependencies (e.g., ZK needs database)
- Docker Compose starts services in definition order

**Approach:**
- Number service files to control order: 01=database, 17=gateway (last)
- Gateway depends on all other services being ready
- Use `depends_on:` in service definitions for explicit dependencies

**Example:**
Service assembly order in start-all.sh arrays matches startup needs:
1. PostgreSQL (01)
2. Storage services (02-04)
3. Application services (05-11)
4. Infrastructure (12-16)
5. Gateway (17) - last to start

**Date learned:** 2026-02-08

---

### Clean vs Persistent Cleanup
**Context:**
- Sometimes need to restart fresh, sometimes keep database

**Approach:**
- Three cleanup levels:
  1. `stop-all.sh` - stop containers, keep everything else
  2. `stop-and-delete-all.sh` - nuclear option, delete EVERYTHING except persistent DB
  3. Manual DB cleanup - `sudo rm -rf postgresql/postgres_database/*`

**Example:**
Restart with same DB: `./stop-all.sh && ./start-all.sh`
Complete fresh start: `./stop-and-delete-all.sh && sudo rm -rf postgresql/postgres_database/* && ./start-all.sh`

**Date learned:** 2026-02-08

---

## ADempiere Specific Patterns

### Multi-UI Architecture
**Context:**
- Support both legacy ZK UI and modern Vue UI
- Different use cases (internal users vs external)

**Approach:**
- Run both UIs simultaneously in separate containers
- ZK UI (adempiere-zk) runs on Jetty server
- Vue UI (vue-ui) as separate frontend
- Both connect to same backend (adempiere-grpc-server)
- Gateway routes by path

**Example:**
- `/webui` → adempiere-zk container (ZK UI)
- `/vue` → vue-ui container (Vue UI)
- Both use same PostgreSQL database
- Both use same gRPC backend

**Date learned:** 2026-02-08

---

### OpenSearch as Dictionary Cache
**Context:**
- ADempiere Application Dictionary is complex and slow to query
- Need fast access to menu, window, process definitions

**Approach:**
- OpenSearch stores dictionary as indexed documents
- opensearch-setup imports snapshot on first start
- dictionary-rs provides RESTful API to cached dictionary
- Faster than querying PostgreSQL for UI metadata

**Example:**
Services: opensearch-node → opensearch-setup → dictionary-rs
Access via: OpenSearch Dashboard on port 5601

**Date learned:** 2026-02-08

---

## Debugging Patterns

### Container Log Investigation
**Context:**
- Service not starting or behaving incorrectly
- Need to see what's happening inside container

**Approach:**
- Check logs: `docker container logs <container-name>`
- Use less for long logs: `docker container logs <container> | less`
- Exec into container: `docker exec -it <container> bash`
- Check env vars inside: `docker inspect <container>`

**Example:**
```bash
docker container logs adempiere-ui-gateway.postgresql
docker exec -it adempiere-ui-gateway.postgresql bash
```

**Date learned:** 2026-02-08

---

### Configuration Validation
**Context:**
- Want to verify docker-compose file before running
- Check variable substitution results

**Approach:**
- Use `docker compose convert` to see final configuration
- Shows all variables resolved
- Useful for debugging env var issues

**Example:**
```bash
cp env_template.env .env
docker compose convert
```

**Date learned:** 2026-02-08
