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
