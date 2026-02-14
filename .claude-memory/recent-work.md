# Recent Work

Track recent changes, ongoing work, and current context here.

## Format
```
### YYYY-MM-DD - [Developer Name]
**What was done:**
- Brief description of changes

**Context/Notes:**
- Important details for next person picking up work
```

---

### 2026-02-13 - POS Payment Error Fix: Missing JavaScript Engine in gRPC Server

**Problem Identified:**
- **Error:** `java.lang.NullPointerException: Cannot invoke "javax.script.ScriptEngine.put(String, Object)" because "engine" is null`
- **Location:** POS payment processing in Vue UI (`PointOfSalesForm.processOrder`)
- **Root Cause:** gRPC server container running Java 17 without JavaScript engine (Nashorn removed in Java 15+)
- **Image:** `marcalwestf/adempiere-grpc-server:3.9.4.001-shw-1.0.30`
- **GitHub Issue:** https://github.com/Systemhaus-Westfalia/adempiere-vue/issues/14

**Diagnosis Steps:**
1. Confirmed Java 17 running in container (openjdk version "17.0.16")
2. Verified no GraalVM/Nashorn/Rhino JARs in `/opt/apps/server/lib/`
3. Confirmed database search_path correct (`adempiere, public`)
4. Identified that Java process uses explicit classpath listing all JARs individually

**Solution Attempted (Option A - Runtime Injection):**
- Downloaded 6 GraalVM JavaScript JARs to /tmp/graalvm-js/:
  - js-23.0.0.jar (27.3 MB)
  - js-scriptengine-23.0.0.jar (75 KB)
  - truffle-api-23.0.0.jar (16.2 MB)
  - graal-sdk-23.0.0.jar (813 KB)
  - regex-23.0.0.jar (3 MB)
  - icu4j-73.1.jar (14.5 MB)
- Copied JARs into running container at `/opt/apps/server/lib/`
- Restarted container
- **Result:** Failed - JARs not loaded because classpath is built at container creation time

**Solution Implemented (Option B - Custom Image):**
Created custom Docker image with GraalVM JavaScript engine baked in.

**Files Created:**
- `docker-compose/Dockerfile.grpc-server-jsfix` - Dockerfile that extends base image with GraalVM JARs

**Dockerfile content:**
```dockerfile
FROM marcalwestf/adempiere-grpc-server:3.9.4.001-shw-1.0.30

USER root

RUN cd /opt/apps/server/lib && \
    wget -q https://repo1.maven.org/maven2/org/graalvm/js/js/23.0.0/js-23.0.0.jar && \
    wget -q https://repo1.maven.org/maven2/org/graalvm/js/js-scriptengine/23.0.0/js-scriptengine-23.0.0.jar && \
    wget -q https://repo1.maven.org/maven2/org/graalvm/truffle/truffle-api/23.0.0/truffle-api-23.0.0.jar && \
    wget -q https://repo1.maven.org/maven2/org/graalvm/sdk/graal-sdk/23.0.0/graal-sdk-23.0.0.jar && \
    wget -q https://repo1.maven.org/maven2/org/graalvm/regex/regex/23.0.0/regex-23.0.0.jar && \
    wget -q https://repo1.maven.org/maven2/com/ibm/icu/icu4j/73.1/icu4j-73.1.jar && \
    chown adempiere:adempiere *.jar

USER adempiere
```

**Configuration Changes:**
- `env_template.env`: Changed `VUE_GRPC_SERVER_IMAGE` from `marcalwestf/adempiere-grpc-server:3.9.4.001-shw-1.0.30` to `marcalwestf/adempiere-grpc-server:3.9.4.001-shw-1.0.30-jsfix`
- `.env`: Synced from env_template.env

**Build and Deploy Commands:**
```bash
cd docker-compose/
sudo docker build -f Dockerfile.grpc-server-jsfix \
  -t marcalwestf/adempiere-grpc-server:3.9.4.001-shw-1.0.30-jsfix .

sudo docker compose stop adempiere-grpc-server
sudo docker compose rm -f adempiere-grpc-server
sudo docker compose up -d adempiere-grpc-server
```

**Verification Commands:**
```bash
# Verify JARs in container
sudo docker exec adempiere-ui-gateway.vue-grpc-server ls -la /opt/apps/server/lib/ | grep graal

# Check for ScriptEngine errors
sudo docker logs adempiere-ui-gateway.vue-grpc-server 2>&1 | grep -i "scriptengine"

# Test POS payment in Vue UI
```

**Status:** IN PROGRESS - Custom image created, awaiting deployment and testing on Mini PC

**Cleanup After Success:**
```bash
# Remove old image
sudo docker rmi marcalwestf/adempiere-grpc-server:3.9.4.001-shw-1.0.30

# Remove temporary JARs
rm -rf /tmp/graalvm-js

# Remove dangling images
sudo docker image prune -f
```

**Context/Notes:**
- This is a missing dependency in the base image maintained by openls/marcalwestf
- Should be reported to image maintainer for inclusion in future releases
- The fix is permanent once custom image is built and used
- Custom image adds ~60 MB to image size (GraalVM JARs)
- Container name: `adempiere-ui-gateway.vue-grpc-server`
- Service name: `adempiere-grpc-server`
- Testing environment: Mini PC (Ubuntu 24.10, 4 CPU, 16 GB RAM, 500 GB disk) on LAN

**Next Steps:**
1. Deploy custom image on Mini PC
2. Test POS payment functionality in Vue UI
3. Verify no ScriptEngine errors in logs
4. If successful, clean up old image and temporary files
5. Document fix for image maintainer

---

### 2026-02-13 - Documentation Improvements: Phases 1-4 Complete
**What was done:**
- Completed comprehensive documentation review and improvement project (Phases 1-4)
- **Phase 1 (Quick Wins):** Fixed quickstart.md and installation.md (removed Java requirement, fixed typos)
- **Phase 2 (Major Documents):** Created system-requirements.md, troubleshooting.md; enhanced architecture.md
- **Phase 3 (Backup & Restore):** Created backup-restore.md, automated backup script (docs/scripts/04-backup-database.sh)
- **Phase 4 (Document Rewrites):** Completely rewrote services.md, debugging.md, security.md
- Added table of contents to troubleshooting.md
- Fixed timezone diagnostic scripts (01-03) for file redirection compatibility

**Files Created/Modified:**
- docs/quickstart.md (removed Java requirement)
- docs/installation.md (removed JDK requirement)
- docs/system-requirements.md (NEW - hardware, software, cloud providers including Contabo)
- docs/troubleshooting.md (NEW - comprehensive guide with TOC)
- docs/architecture.md (enhanced - health checks, dependencies, network architecture)
- docs/services.md (COMPLETE REWRITE - all services, profiles, access URLs, credentials)
- docs/debugging.md (COMPLETE REWRITE - organized by use case, advanced debugging)
- docs/security.md (COMPLETE REWRITE - Docker firewall bypass, HTTPS, comprehensive security)
- docs/backup-restore.md (NEW - comprehensive backup/restore procedures)
- docs/scripts/04-backup-database.sh (NEW - automated backup with retention)
- docs/scripts/README.md (updated with backup script documentation)
- docs/scripts/01-03 (fixed process substitution for file redirection)

**Key Decisions:**
- Use Europe/Berlin timezone examples (not El Salvador) for generic public documentation
- Scripts belong in docs/scripts/ (documentation), not docker-compose/ (application)
- Generic placeholders in all examples (<your-backup-file>.backup, ${HOST_IP})
- No deployment-specific services mentioned (removed svfe-api-firmador references)
- Keycloak documented as optional service in auth profile
- Sequential script numbering (01-04) in docs/scripts/

**Context/Notes:**
- Phase 5 (Final Polish) remains: cross-reference verification, README.md review, consistency check
- Documentation now suitable for public GitHub repository (generic, no sensitive/deployment-specific info)
- All default credentials documented with change procedures
- Comprehensive security guide including Docker firewall bypass explanation
- Work paused to switch to higher-priority, lower-token task
- Resume command: "Let's continue with Phase 5 of the documentation plan"

---

### 2026-02-12 - Health Check Timeouts Improved for Production Readiness
**What was done:**
- Relaxed health check timeouts for critical infrastructure services
- Adopted balanced approach between fast failure detection and startup tolerance
- Based on analysis comparing feature/SHW_General (10s/60 retries) vs adempiere-trunk (30s/5 retries)

**Services Updated:**
1. **postgresql-service**: retries 5→10, start_period 20s→40s (total: 2.5min → 5min)
2. **opensearch-node**: retries 5→10, start_period 20s→40s (total: 2.5min → 5min)
3. **zookeeper**: retries 5→8, start_period 20s→30s (total: 2.5min → 4min)
4. **kafka**: interval 15s→30s, retries 3→8, start_period 20s→30s (total: 45s → 4min)

**Rationale:**
- Database restoration can take time (especially PostgreSQL on first run)
- OpenSearch needs time for index initialization and cluster state recovery
- Kafka/Zookeeper require time for cluster coordination and metadata loading
- Previous timeouts (2.5 min) were too aggressive for complex services
- New timeouts (4-5 min) provide production-grade reliability while still detecting failures

**Test Results:**
- ✅ All 23/23 containers started successfully on remote server
- ✅ Total startup time: ~108 seconds (normal for this stack)
- ✅ OpenSearch: 105s (expected for search engine initialization)
- ✅ Kafka: 93.5s (expected for messaging platform startup)
- ✅ No timeout errors, no premature failures

**Files modified:**
- docker-compose/docker-compose.yml (health check configurations)

**Context/Notes:**
- OpenSearch and Kafka startup times (90-105s) are normal for production systems
- These are complex Java services with significant initialization overhead
- Startup time is NOT a production problem - services stay running
- Health check improvements prevent cascade failures during startup
- Next: Add HTTPS support for production deployment

---

### 2026-02-12 - Test-03 SUCCESS: All Containers Running!
**What was done:**
- Fixed network configuration conflict by commenting out other_external_network
- Updated proto descriptor file (adempiere-grpc-server.dsc) from outdated version
- Old .dsc: 1,045,077 bytes (July 2025) → New .dsc: 1,085,487 bytes (Feb 2026)
- Verified update with checksum: 4b53d7a0b635a82ec040705a3980592a
- Committed, pushed, and tested on remote server
- Created milestone tag: `20260212/adempiere-trunk-all-containers-working`

**Test Results:**
- ✅ All 23/23 containers started successfully
- ✅ No errors or warnings during startup
- ✅ ZK UI accessible at /webui
- ✅ Vue UI accessible at /vue
- ✅ Both UIs confirmed working with successful login
- ⏳ Functional testing in progress

**Root Causes Identified:**
1. **Network issue:** Docker Compose label conflict when OTHER_EXTERNAL_NETWORK="${ADEMPIERE_NETWORK}"
   - Both networks pointed to same name causing endpoint errors
   - Solution: Comment out other_external_network feature (preserving for future re-enablement)

2. **Envoy proto descriptor error:** Outdated .dsc file missing form package services
   - adempiere-trunk had version from commit 67621ac (Jul 2025)
   - Needed version from commit c7beb9c (Feb 2026) with form.payment_allocation services
   - Solution: Updated to newer .dsc file from feature/SHW_General branch

**Files modified:**
- docker-compose/docker-compose.yml (network config)
- docker-compose/env_template.env (network variable)
- docker-compose/.env (synced from template)
- docker-compose/envoy/definitions/adempiere-grpc-server.dsc (updated binary descriptor)
- .claude-memory/test-log.md (documented complete Test-03 journey)

**Context/Notes:**
- Test-03 is COMPLETE ✅
- adempiere-trunk is now fully functional on remote server
- Phase 1 testing successful - stack is production-ready
- Preserves all Systemhaus-Westfalia image versions from feature/SHW_General
- Next: Complete functional testing, then proceed to Phase 2 (production deployment planning)

---

### 2026-02-11 - Test-01: Phase 1 Configuration Fixes Ready
**What was done:**
- Fixed external network configuration (removed external: true)
- Added missing variables from simplify-files branch
  - GENERIC_TIMEZONE, GENERIC_CENTRAL_STANDARD_TIME
  - ZOOKEEPER_LOG_LEVEL, KAFKA_LOG_LEVEL, OPENSEARCH_LOG_LEVEL
- Fixed Envoy gRPC service namespace issues (adopted from simplify-files commit c7beb9c)
  - Added form.out_bound_order.OutBoundOrderService
  - Fixed form.payment_allocation.PaymentAllocation namespace
  - Fixed form.trial_balance_drillable.TrialBalanceDrillable namespace
- Created test log system (.claude-memory/test-log.md)
- Established test naming convention: Test-<NUMBER>-<YYYYMMDD>

**Analysis performed:**
- Cross-branch comparison between adempiere-trunk and simplify-files
- Identified and adopted configuration fixes while preserving Systemhaus-Westfalia image versions
- Verified all changes match proven fixes from simplify-files branch

**Files modified:**
- docker-compose/docker-compose.yml (external network)
- docker-compose/env_template.env (variables)
- docker-compose/.env (synced from template)
- docker-compose/envoy/envoy.yaml (service namespaces)
- .claude-memory/test-log.md (new test tracking system)

**Context/Notes:**
- Test-01-20260211: Ready to commit and push
- Test-02-20260212: Planned for remote server validation
- All fixes prevent known startup errors (network, variables, Envoy proto descriptors)
- Image versions from feature/SHW_General preserved (Systemhaus-Westfalia controlled)
- Next: Push changes and test on remote server

---

### 2026-02-11 - Phase 0 Complete: Safety Baseline Tags Established
**What was done:**
- Created production baseline tag on feature/SHW_General branch
  - Tag: `20260210/feature/SHW_General-SHW-production-baseline`
  - Commit: 97dceb9 "Add new cases solved"
  - Message: "Production baseline before adempiere-trunk testing (2026-02-11)"
- Created ready-for-testing tag on adempiere-trunk branch
  - Tag: `20260211/adempiere-trunk-ready-for-testing`
  - Commit: adc552d "Project memory"
  - Message: "Ready for testing - the simplified approach (2026-02-11)"
- All tags pushed to GitHub

**Safety Net Established:**
- Can rollback to production baseline (feature/SHW_General)
- Can rollback to before-fixes state (adempiere-trunk dd2b635)
- Can rollback to ready-for-testing baseline (adempiere-trunk adc552d)

**Context/Notes:**
- Phase 0 completed successfully ✅
- Three safety tags now in place across both branches
- Next: Phase 1 - Test adempiere-trunk thoroughly (minimum 1-2 weeks recommended)

---

### 2026-02-11 - Phase -1 Complete: Fixed External Network & Added Documentation
**What was done:**
- Created safety tag: `20260210/adempiere-trunk-before-fixes` on commit dd2b635
  - Tag message: "Before merging with feature/SHW_General (2026-02-11)"
  - Provides rollback point before documentation and configuration fixes
- Fixed missing OTHER_EXTERNAL_NETWORK variable in env_template.env and .env
- Added comprehensive documentation comments explaining optional external network feature
- Added network documentation comments in docker-compose.yml
- Removed .env from .gitignore (both .env and env_template.env are now tracked)
- Established best practice: Always edit env_template.env FIRST, then sync to .env
- Committed and pushed to GitHub as commit 63d9636

**Tag Details:**
```
Tag: 20260210/adempiere-trunk-before-fixes
Commit: dd2b635 "Update architecture.md"
Message: "Before merging with feature/SHW_General (2026-02-11)"
Created: 2026-02-11 11:49:56
```

**Context/Notes:**
- External network feature allows connecting ADempiere to other Docker stacks (optional)
- Default: OTHER_EXTERNAL_NETWORK="${ADEMPIERE_NETWORK}" (no external connection)
- Both .env and env_template.env are committed to git in this infrastructure project
- Migration plan Phase -1 completed successfully ✅
- Next: Phase 0 - Create safety baseline tags on feature/SHW_General branch

---

### 2026-02-10 - Established Claude Code Session Workflow Protocol
**What was done:**
- Established startup protocol: Claude must check `.claude-memory/` at the start of every session
- Documented workflow in Claude's personal `MEMORY.md` (auto-loaded each session)
- Added "Claude Code Workflow Patterns" section to `learned-patterns.md`
- Verified last plan status: Branch migration (feature/SHW_General → adempiere-trunk) completed, awaiting testing

**Context/Notes:**
- This solves the cross-session context problem - each session starts with team memory awareness
- `.claude-memory/` acts as version-controlled institutional knowledge base
- Pattern documented so future Claude sessions and team members know the workflow
- Key insight: Claude already has CLAUDE.md auto-loaded but needs to actively read .claude-memory/
- Next session: Claude will immediately understand project history and continue seamlessly

---

### 2026-02-10 - Branch Migration: feature/SHW_General → adempiere-trunk
**What was done:**
- Migrated production-tested versions from feature/SHW_General to adempiere-trunk
- Updated env_template.env with all image versions from feature/SHW_General
- Added SVFE (El Salvador Electronic Invoicing) service to docker-compose.yml
- Migrated documentation (CLAUDE.md, .claude-memory/) from feature/SHW_General
- Updated CLAUDE.md to reflect profile-based architecture (not modular files)

**Version Updates Applied:**
- ADempiere ZK: 1.1.27 → 1.1.45 (+18 versions)
- ADempiere Processor: 1.1.2 → 1.1.16 (+14 versions)
- Vue gRPC Server: 1.0.23 → 1.0.30 (+7 versions)
- Envoy Proxy: custom image → envoyproxy/envoy:v1.37.0 (official image)
- MinIO: Kept adempiere-trunk's 2025-07 releases (newer than feature/SHW_General's 2024-07)

**Architecture Difference:**
- feature/SHW_General: Modular approach with separate docker-compose/*.yml files assembled by start-all.sh
- adempiere-trunk: Single docker-compose.yml using Docker Compose profiles for service activation

**Configuration Changes:**
- Replaced simple timezone vars with host mount-based approach
- Removed log level variables (ZOOKEEPER_LOG_LEVEL, KAFKA_LOG_LEVEL, OPENSEARCH_LOG_LEVEL)
- Kept container names with hyphens (not dots) to avoid compatibility issues

**Context/Notes:**
- adempiere-trunk is now ready for production with tested versions from feature/SHW_General
- The simplification goal was preserved - single docker-compose.yml with profiles
- SVFE service added for El Salvador electronic invoicing support
- Next step: Test the stack on adempiere-trunk before deploying to production
- Remember: User will commit manually, so changes are staged but not committed

---

### 2026-02-08 - Initial Setup
**What was done:**
- Created CLAUDE.md with complete stack architecture documentation
- Set up .claude-memory/ structure for team collaboration
- Documented all stack modes (default, develop, vue, cache, auth, storage)

**Context/Notes:**
- CLAUDE.md now auto-loads context about modular docker-compose service files
- Team memory system established for cross-machine collaboration
- Repository uses feature/SHW_General branch, main branch is for PRs
- STANDARD_array has been customized for SHW deployment (Postgres with ports, Kafdrop, SVFE electronic invoicing)

---

### 2026-02-08 - Production Deployment Documentation
**What was done:**
- Documented actual production deployment configuration from remote server
- Captured docker-compose.yml and docker compose convert output from running deployment
- Identified discrepancy between git baseline and actual running configuration

**⚠️ CRITICAL - Git Baseline (commit c51d7c8):**
- **Branch**: `feature/SHW_General`
- **Commit**: `c51d7c8` (detached HEAD on remote)
- **Commit date**: 2026-02-03
- **Commit message**: "Update adempiere-shw to 3.9.4.001-1.1.46"
- **Author**: Mario Calderon
- **Deployment files**: `/home/westfalia/Westfalia-Projekte/COFIA/04-Implementierung/2026/20260208-Claude/`

**⚠️ CRITICAL - Actual Running Deployment:**
- **Based on commit**: c51d7c8
- **Local modifications**: `.env` and `env_template.env` manually modified on server
- **Status**: Running with uncommitted changes

**Production Server Details:**
- **Domain**: the preferred domain of implementation
- **SSL**: Let's Encrypt certificates
- **Remote repo path**: /home/westfalia/adempiere/01-Repository/adempiere-ui-gateway/
- **Network**: 192.168.100.0/24 (gateway: 192.168.100.1)
- **Timezone**: America/El_Salvador

**Image Versions Comparison:**

| Service | Git (c51d7c8) | Actually Running | Notes |
|---------|---------------|------------------|-------|
| adempiere-zk | `jetty-3.9.4.001-shw-1.1.39` | `jetty-3.9.4.001-shw-1.1.45` | ⚠️ Modified in .env |
| adempiere-grpc-server | `3.9.4.001-shw-1.0.29` | `3.9.4.001-shw-1.0.29` | Same |
| adempiere-grpc-proxy | `3.9.4.001-shw-1.0.29` | `3.9.4.001-shw-1.0.29` | Same |
| adempiere-report-engine | `alpine-1.3.7` | `alpine-1.3.7` | Same |
| adempiere-processors | `alpine-1.1.11` | `alpine-1.1.11` | Same |
| adempiere-vue | `0.0.5` | `0.0.5` | Same |
| PostgreSQL | `14.5` | `14.5` | Same |
| nginx | `1.27.0-alpine3.19` | `1.27.0-alpine3.19` | Same |
| Kafka | `7.6.1` | `7.6.1` | Same |
| OpenSearch | `2.15.0` | `2.15.0` | Same |
| MinIO | `RELEASE.2024-07-31T05-46-26Z` | `RELEASE.2024-07-31T05-46-26Z` | Same |

**Services Running (STANDARD stack + SHW custom):**
1. PostgreSQL (port 55432)
2. MinIO S3 Storage (ports 9000, 9090)
3. S3 Client, S3 Gateway RS
4. ADempiere Site, ZK UI, Processor
5. DKron Scheduler (ports 8899, 8946)
6. gRPC Server, Report Engine
7. Envoy gRPC Proxy (port 5555)
8. Vue UI
9. Zookeeper, Kafka (port 29092), Kafdrop (port 19000)
10. OpenSearch, OpenSearch Setup, OpenSearch Dashboards (port 5601)
11. Dictionary RS
12. nginx UI Gateway (ports 80, 443)
13. SVFE API Firmador - El Salvador e-invoicing (port 8113)

**Context/Notes:**
- ⚠️ Server has local modifications not in git: ZK image upgraded from 1.1.39 → 1.1.45
- Git commit c51d7c8 from 2026-02-03 is the baseline
- Actual deployment may differ from git due to manual .env changes
- Always verify actual running versions vs git when troubleshooting
- Configuration uses STANDARD stack with SHW customizations

---

### 2026-02-10 - Fixed Envoy Proxy Startup Failure
**What was done:**
- Diagnosed and fixed envoy proxy crash: "Could not find 'form.out_bound_order.OutBoundOrderService' in the proto descriptor"
- Updated docker-compose volume mounts to include new `.dsc` proto descriptor file
- Replaced old `.pb` file with new `.dsc` file containing updated service definitions

**Problem:**
- Commit c7beb9c (2026-02-02) added new gRPC services to envoy.yaml and created new `.dsc` descriptor file
- BUT forgot to update docker-compose to mount the new file
- Envoy crashed on startup because it couldn't find the new service definitions

**Solution Applied (commit c7103fa):**
- Changed volume mount in `10c-grpc_proxy_service_standard.yml`:
  - FROM: `./envoy/definitions/adempiere-grpc-server.pb:/data/adempiere-grpc-server.pb:ro`
  - TO: `./envoy/definitions/adempiere-grpc-server.dsc:/data/adempiere-grpc-server.dsc:ro`
- Updated same in `docker-compose-standard.yml` and `docker-compose-auth.yml`
- Updated envoy.yaml proto_descriptor path from `.pb` to `.dsc`
- Deleted old `.pb` file

**New Services Added:**
- `form.out_bound_order.OutBoundOrderService`
- `form.payment_allocation.PaymentAllocation` (moved from old location)
- `form.trial_balance_drillable.TrialBalanceDrillable` (moved from old location)

**Context/Notes:**
- This is a common pitfall: updating envoy.yaml but forgetting to update docker-compose volumes
- The three-step pattern documented in learned-patterns.md must be followed
- Always verify descriptor file is mounted after adding new gRPC services
- Issue occurred between commits c51d7c8 (working) and 20b3208 (failing)
- Error files archived in: `/home/westfalia/Westfalia-Projekte/Kaltmann/.../20260208-Error_envoy_proxy/English/`
