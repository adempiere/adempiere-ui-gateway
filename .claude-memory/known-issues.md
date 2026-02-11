# Known Issues

Document bugs, gotchas, workarounds, and debugging tips here.

## Format
```
### Issue: [Brief description]
**Symptoms:**
- What happens

**Cause:**
- Why it happens

**Workaround/Solution:**
- How to fix it

**Date discovered:** YYYY-MM-DD
```

---

## Envoy Proxy / gRPC Issues

### Envoy Crashes: "Could not find service in proto descriptor"
**Symptoms:**
- Container `adempiere-ui-gateway.envoy.grpc.proxy` fails to start (exit code 1)
- Log shows: `transcoding_filter: Could not find 'form.out_bound_order.OutBoundOrderService' in the proto descriptor`
- Other services start successfully, but envoy blocks dependent services (nginx gateway)

**Cause:**
- envoy.yaml was updated to transcode new gRPC services (OutBoundOrderService, PaymentAllocation, TrialBalanceDrillable)
- New proto descriptor file (`.dsc`) was added with service definitions
- **BUT** docker-compose volumes were NOT updated to mount the new descriptor file
- Envoy couldn't find the service definitions because the file wasn't available in the container

**Root Cause - The Three-Step Update Pattern:**
When adding new gRPC services, THREE things must be updated:
1. ✅ Proto descriptor file (`.dsc` or `.pb`) - add service definitions
2. ✅ `envoy.yaml` - add services to transcoding list
3. ⚠️ **Docker-compose volumes** - mount the updated descriptor file ← **This was missed!**

**Solution:**
Update all docker-compose files that define the grpc-proxy service to mount the correct descriptor file:

1. Change in `10c-grpc_proxy_service_standard.yml`:
   ```yaml
   # OLD (wrong):
   - ./envoy/definitions/adempiere-grpc-server.pb:/data/adempiere-grpc-server.pb:ro

   # NEW (correct):
   - ./envoy/definitions/adempiere-grpc-server.dsc:/data/adempiere-grpc-server.dsc:ro
   ```

2. Update the same in:
   - `docker-compose-standard.yml`
   - `docker-compose-auth.yml`
   - Any other compose files that define grpc-proxy

3. Update `envoy.yaml` proto_descriptor path:
   ```yaml
   proto_descriptor: "/data/adempiere-grpc-server.dsc"  # Changed from .pb to .dsc
   ```

**Timeline:**
- 2026-02-02 (commit c7beb9c): Added `.dsc` file + new services to envoy.yaml, but forgot docker-compose update
- 2026-02-08 to 2026-02-10: Error discovered and investigated
- 2026-02-10 (commit c7103fa): Fixed by updating docker-compose volume mounts

**How to Diagnose:**
1. Check if service definition exists: `grep -a "ServiceName" path/to/descriptor.dsc`
2. Check what's mounted: `cat docker-compose/10c-grpc_proxy_service_standard.yml | grep -A 10 "volumes:"`
3. Compare commits: `git diff working_commit..failing_commit docker-compose/envoy/`

**Date discovered:** 2026-02-08
**Date resolved:** 2026-02-10

---

## Deployment & Configuration

### Server Has Local .env Modifications Not in Git
**Symptoms:**
- Running container versions differ from what's expected based on git commit
- `docker compose convert` output shows different image versions than env_template.env in git

**Cause:**
- .env and env_template.env files manually modified on production server
- Changes not committed to git (intentional for testing or quick fixes)

**Workaround/Solution:**
- Always document both: git baseline commit AND actual running configuration
- Use `docker compose convert` on server to see actual resolved values
- Check running container versions: `docker ps --format "{{.Names}}: {{.Image}}"`
- When troubleshooting, verify against actual deployment, not just git

**Example (as of 2026-02-08):**
- Git commit c51d7c8: adempiere-zk `jetty-3.9.4.001-shw-1.1.39`
- Actually running: adempiere-zk `jetty-3.9.4.001-shw-1.1.45`

**Date discovered:** 2026-02-08

---

## Docker & Networking

### Docker Bypasses Host Firewall
**Symptoms:**
- Exposed container ports accessible even when host firewall (UFW) blocks them
- Security risk if host is directly exposed to internet

**Cause:**
- Docker manipulates iptables directly, bypassing firewall rules
- This is Docker's standard behavior by design

**Workaround/Solution:**
- ALWAYS use an external firewall (cloud provider firewall, hardware firewall)
- Never expose host directly to internet without upstream firewall protection
- See README.md Security Information section

**Date discovered:** 2026-02-08 (documented in README)

---

### Database Restore Not Running
**Symptoms:**
- Database not restored from seed file even when seed.backup exists
- initdb.sh appears to be skipped

**Cause:**
- `postgresql/postgres_database/` directory has existing contents from previous run
- initdb.sh only runs when database doesn't exist AND directory is empty
- If docker-compose file uses `image:` instead of `build:`, Dockerfile is ignored

**Workaround/Solution:**
- Delete database directory contents: `sudo rm -rf postgresql/postgres_database/*`
- Ensure docker-compose service file uses `build:` with Dockerfile
- Check that seed file is named correctly (default: `seed.backup`)

**Date discovered:** 2026-02-08 (from README architecture analysis)

---

### Legacy vs Modular Service Files Confusion
**Symptoms:**
- Finding both `docker-compose-standard.yml` and `01a-postgres_service_*.yml` files
- Unclear which files are actually used

**Cause:**
- Repository transitioned from legacy monolithic files to modular service files
- Legacy files kept for comparison but no longer recommended

**Workaround/Solution:**
- Always use `start-all.sh -d [mode]` (modular approach)
- Only use `start-all.sh -d [mode] -l` for legacy if explicitly needed for debugging
- Modular service files are in `docker-compose/##[a-z]-*_service_*.yml` format

**Date discovered:** 2026-02-08 (from README)

---

## Container Management

### docker-compose.yml Generated Dynamically
**Symptoms:**
- No docker-compose.yml in repository
- Cannot run `docker compose up` directly

**Cause:**
- docker-compose.yml is dynamically generated by `start-all.sh`
- Assembled from individual service files based on selected mode

**Workaround/Solution:**
- Always use `start-all.sh -d [mode]` to generate and run
- File is deleted by `stop-all.sh` after stopping services
- This is intentional design for modular service composition

**Date discovered:** 2026-02-08

---

### Wrong Container Prefix
**Symptoms:**
- Containers named with unexpected prefix (e.g., different client name)

**Cause:**
- `COMPOSE_PROJECT_NAME` in env_template.env determines all container/image names
- env_template.env not copied to .env or outdated .env used

**Workaround/Solution:**
- Edit `COMPOSE_PROJECT_NAME` in `env_template.env`
- Run `start-all.sh` which automatically copies to `.env`
- Or manually: `cp env_template.env .env` before running docker compose

**Date discovered:** 2026-02-08 (from README)

---

## File Permissions

### Cannot Access postgres_database Directory
**Symptoms:**
- Permission denied when trying to ls or access postgresql/postgres_database/
- Commands fail with "Permission denied"

**Cause:**
- PostgreSQL container runs as postgres user (different UID)
- Directory owned by container's postgres user, not host user

**Workaround/Solution:**
- Use sudo for operations: `sudo ls postgresql/postgres_database/`
- Use Docker exec to access from inside container: `docker exec -it adempiere-ui-gateway.postgresql bash`
- For cleanup: `sudo rm -rf postgresql/postgres_database/*`

**Date discovered:** 2026-02-08 (observed during analysis)
