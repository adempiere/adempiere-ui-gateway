# Test Log

Track all test iterations for adempiere-trunk branch deployment and validation.

## Test Naming Convention

**Format:** `Test-<CONSECUTIVE_NUMBER>-<YYYYMMDD>`

**Example:** `Test-01-20260211`

---

## Test-03-20260212 (Remote Server - Complete Fix)

**Date:** 2026-02-12
**Environment:** Remote server (production-like)
**Branch:** adempiere-trunk
**Tag:** `20260212/adempiere-trunk-all-containers-working`
**Commits:**
- 21cf002 (Disable external network feature)
- [latest] (Update proto descriptor file)

### Test Objectives
1. Fix network creation error (other_external_network conflict)
2. Fix envoy-grpc-proxy proto descriptor error
3. Achieve 23/23 containers running successfully
4. Verify UI access (ZK and Vue)

### Issues Found & Fixed

#### Issue 1: Network Configuration Conflict
**Problem:** Docker Compose label conflicts when `OTHER_EXTERNAL_NETWORK="${ADEMPIERE_NETWORK}"`
- Both `adempiere_network` and `other_external_network` pointed to same network name
- Caused endpoint errors and container creation failures
- Result: 22/23 containers created but envoy-grpc-proxy failed

**Solution:**
- Commented out `other_external_network` declaration in docker-compose.yml
- Commented out network references in all 22 services
- Added detailed re-enablement instructions for future use
- Files: docker-compose.yml, env_template.env, .env

#### Issue 2: Outdated Proto Descriptor File
**Problem:** Envoy crashes with error:
```
transcoding_filter: Could not find 'form.payment_allocation.PaymentAllocation'
in the proto descriptor
```

**Root Cause Analysis:**
- adempiere-trunk had OLD .dsc file: 1,045,077 bytes (from commit 67621ac, July 2025)
- feature/SHW_General had NEW .dsc file: 1,085,487 bytes (from commit c7beb9c, Feb 2026)
- New file includes form package services missing in old file
- Volume mounts were correct, but mounted file was outdated

**Solution:**
- Updated adempiere-grpc-server.dsc to version from commit c7beb9c
- Verified checksum: 4b53d7a0b635a82ec040705a3980592a
- File now contains all required services:
  - form.payment_allocation.PaymentAllocation
  - form.trial_balance_drillable.TrialBalanceDrillable
  - form.out_bound_order.OutBoundOrderService
- File: docker-compose/envoy/definitions/adempiere-grpc-server.dsc

### Test Procedure
```bash
# On local machine
git add docker-compose/envoy/definitions/adempiere-grpc-server.dsc
git commit -m "Test-03: Update proto descriptor..."
git push origin adempiere-trunk

# On remote server
cd /path/to/adempiere-ui-gateway_SHW
git pull origin adempiere-trunk
cd docker-compose
sudo ./stop-all.sh
sudo ./start-all.sh

# Verify
docker compose ps -a  # Check all 23 containers
docker logs adempiere-ui-gateway.envoy-grpc-proxy  # No errors
```

### Expected Results
- ✅ No network creation errors
- ✅ All 23/23 containers start successfully
- ✅ No proto descriptor errors from envoy
- ✅ ZK UI accessible at /webui
- ✅ Vue UI accessible at /vue
- ✅ No warnings or errors in startup logs

### Actual Results
✅ **SUCCESS - All objectives achieved!**
- All 23/23 containers started successfully
- No errors or warnings during startup
- ZK UI accessible and working at /webui
- Vue UI accessible and working at /vue
- Functional testing in progress

### Key Learnings
1. **Docker network labels:** When two networks point to same name, remove `external: true`
2. **Volume mounts vs file content:** Correct volume mounts don't guarantee correct file version
3. **Proto descriptor updates:** Always check .dsc file version when adding new gRPC services
4. **Cross-branch dependencies:** Envoy config (envoy.yaml) and proto files (.dsc) must be in sync
5. **Verification methods:** Use checksums to verify binary file updates (md5sum)

### Files Modified
- docker-compose/docker-compose.yml (commented other_external_network)
- docker-compose/env_template.env (commented OTHER_EXTERNAL_NETWORK)
- docker-compose/.env (synced from template)
- docker-compose/envoy/definitions/adempiere-grpc-server.dsc (updated to new version)

### Status
✅ **COMPLETE** - All containers running, UIs accessible, ready for functional testing

### Milestone Tag
**Tag:** `20260212/adempiere-trunk-all-containers-working`
**Pushed to:** origin/adempiere-trunk
**Purpose:** Marks first fully working state of adempiere-trunk on remote server

---

## Test-02-20260212 (Remote Server Validation)

**Date:** 2026-02-12 (Planned)
**Environment:** Remote server (production-like)
**Branch:** adempiere-trunk
**Base Commit:** TBD (after Test-01 push)

### Test Objectives
1. Validate external network fix (no "network not found" error)
2. Validate missing variables fix (no WARN messages)
3. Validate Envoy service namespace fix (no proto descriptor errors)
4. Confirm all services start successfully
5. Verify basic functionality (UI access, API endpoints)

### Test Procedure
```bash
# 1. Pull latest changes
cd /path/to/adempiere-ui-gateway_SHW
git pull origin adempiere-trunk

# 2. Start the stack
cd docker-compose
sudo ./start-all.sh

# 3. Monitor startup
docker compose ps -a

# 4. Check for errors
docker container logs adempiere-ui-gateway.envoy.grpc.proxy
docker container logs adempiere-ui-gateway.zk
docker container logs adempiere-ui-gateway.postgres

# 5. Test access
# - ZK UI: http://<HOST_IP>/webui
# - Vue UI: http://<HOST_IP>/vue
# - API: http://<HOST_IP>/api/
```

### Expected Results
- ✅ No "network not found" error
- ✅ No WARN messages about GENERIC_TIMEZONE, LOG_LEVEL variables
- ✅ Envoy starts without proto descriptor errors
- ✅ All services show "Up" status
- ✅ UIs are accessible
- ✅ API responds

### Actual Results
*To be filled after testing*

### Issues Found
*To be documented*

### Status
⏳ **PENDING** - Awaiting remote server test

---

## Test-01-20260211 (Local Configuration Fixes)

**Date:** 2026-02-11
**Environment:** Local development machine
**Branch:** adempiere-trunk
**Commit:** TBD (to be pushed)

### Changes Applied

#### 1. External Network Fix
**Problem:** Network creation error when `OTHER_EXTERNAL_NETWORK="${ADEMPIERE_NETWORK}"`
```
Error: network cofia-test-gateway.network not found
```

**Solution:**
- Removed `external: true` from `other_external_network` in docker-compose.yml
- Updated comments to explain optional external network usage
- Network now created automatically, no conflict when pointing to same name

**Files Modified:**
- `docker-compose/docker-compose.yml`

#### 2. Missing Variables Fix
**Problem:** Multiple WARN messages on startup
```
WARN: The "GENERIC_TIMEZONE" variable is not set
WARN: The "GENERIC_CENTRAL_STANDARD_TIME" variable is not set
WARN: The "ZOOKEEPER_LOG_LEVEL" variable is not set
WARN: The "KAFKA_LOG_LEVEL" variable is not set
WARN: The "OPENSEARCH_LOG_LEVEL" variable is not set
```

**Solution:** Adopted variables from `simplify-files` branch (commits c7beb9c, 86e87d3)
```bash
GENERIC_TIMEZONE="America/El_Salvador"
GENERIC_CENTRAL_STANDARD_TIME="CST6"
ZOOKEEPER_LOG_LEVEL="WARN"
KAFKA_LOG_LEVEL="WARN"
OPENSEARCH_LOG_LEVEL="WARN"
```

**Files Modified:**
- `docker-compose/env_template.env`
- `docker-compose/.env`

#### 3. Envoy gRPC Service Namespace Fix
**Problem:** Envoy crashes with proto descriptor errors (from simplify-files commit c7beb9c)
```
[critical] transcoding_filter: Could not find 'payment_allocation.PaymentAllocation'
in the proto descriptor
```

**Root Cause:** Services in `form` package require `form.` namespace prefix

**Solution:**
- Added missing service: `form.out_bound_order.OutBoundOrderService`
- Fixed namespace: `payment_allocation.PaymentAllocation` → `form.payment_allocation.PaymentAllocation`
- Fixed namespace: `trial_balance_drillable.TrialBalanceDrillable` → `form.trial_balance_drillable.TrialBalanceDrillable`

**Files Modified:**
- `docker-compose/envoy/envoy.yaml`

### Source of Fixes
All fixes adopted from `simplify-files` branch after careful analysis:
- Commit c7beb9cb3d804b569e2588e6055d3c737f07b948 (envoy fixes)
- Commit 86e87d36955719ce1cdca2b0cddeb25f6148a236 (service comment)
- Analysis preserved image versions from feature/SHW_General (Systemhaus-Westfalia controlled)

### Test Results
✅ **Local validation:** Git diff confirmed all changes applied correctly
✅ **Code review:** All modifications match simplify-files proven fixes
⏳ **Runtime validation:** Pending Test-02 on remote server

### Status
✅ **COMPLETE** - Changes committed, ready for push and remote testing

---

## Future Tests Template

### Test-XX-YYYYMMDD (Description)

**Date:** YYYY-MM-DD
**Environment:** [Local/Remote/Production]
**Branch:** adempiere-trunk
**Base Commit:** [commit hash]

#### Test Objectives
- Objective 1
- Objective 2

#### Test Procedure
```bash
# Commands to execute
```

#### Expected Results
- Expected 1
- Expected 2

#### Actual Results
*Document actual outcomes*

#### Issues Found
- Issue 1
- Issue 2

#### Status
⏳ PENDING | 🔄 IN PROGRESS | ✅ PASSED | ❌ FAILED

---

**Last Updated:** 2026-02-11
