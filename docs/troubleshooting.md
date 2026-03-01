# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the ADempiere UI Gateway stack.

## Table of Contents
- [Quick Diagnostic Commands](#quick-diagnostic-commands)
- [Container Health Checks Failing](#container-health-checks-failing)
  - [Normal Startup Times](#1-normal-startup-times-not-an-error)
  - [Insufficient Memory](#2-insufficient-memory)
  - [Port Conflicts](#3-port-conflicts)
- [Database Issues](#database-issues)
  - [Database Won't Restore](#database-wont-restore)
  - [Database Connection Refused](#database-connection-refused)
  - [Database Already Exists](#database-already-exists-no-restore-happening)
- [Timezone Mismatches](#timezone-mismatches)
  - [Symptoms](#symptoms)
  - [Diagnosis](#diagnosis)
  - [Understanding Timezone Configuration](#understanding-timezone-configuration)
- [Container Start/Stop Issues](#container-startstop-issues)
  - [Containers Won't Start](#containers-wont-start)
  - [Containers Keep Restarting](#containers-keep-restarting)
- [Network and Access Issues](#network-and-access-issues)
  - [Can't Access Application (Port 80)](#cant-access-application-port-80)
  - [Can't Access ZK UI or Vue UI](#cant-access-zk-ui-or-vue-ui)
  - [Internal Container Communication Issues](#internal-container-communication-issues)
- [Performance Issues](#performance-issues)
  - [Slow Startup Times](#slow-startup-times)
  - [Slow Application Response](#slow-application-response)
  - [High CPU or Memory Usage](#high-cpu-or-memory-usage)
- [Disk Space Issues](#disk-space-issues)
  - [Out of Disk Space](#out-of-disk-space)
- [Common Error Messages](#common-error-messages)
  - ["driver failed programming external connectivity"](#driver-failed-programming-external-connectivity)
  - ["connection refused" to PostgreSQL](#connection-refused-to-postgresql)
  - ["unhealthy" Status Persists](#unhealthy-status-persists)
  - ["no such file or directory" - seed.backup](#no-such-file-or-directory---seedbackup)
- [POS Application Errors](#pos-application-errors)
  - [ScriptEngine NullPointerException (Groovy AD_Rules)](#scriptengine-nullpointerexception-groovy-ad-rules)
- [Getting Help](#getting-help)
- [Prevention Tips](#prevention-tips)

---

## Quick Diagnostic Commands

Before diving into specific issues, these commands help identify problems.

### Finding Service and Container Names

Many commands below require either a **service name** (used by `docker compose`) or a **container name** (used by `docker` directly). They are different:

```bash
# List all services and their container names (running and stopped)
docker compose ps -a

# Example output:
# NAME                                    SERVICE                  STATUS
# adempiere-ui-gateway.vue-grpc-server    adempiere-grpc-server    running
# adempiere-ui-gateway.postgresql         postgresql-service       running
# adempiere-ui-gateway.nginx-ui-gateway   ui-gateway               running
#
# Left column  → container name  (use with: docker logs, docker exec, docker inspect)
# Middle column → service name   (use with: docker compose logs, docker compose restart)

# List only service names (one per line)
docker compose ps --services

# List only container names (docker native, no compose)
docker ps --format "{{.Names}}"

# List container names with their image
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
```

### General Diagnostics

```bash
# Check which containers are running
docker compose ps -a

# Check container logs (replace <service-name> with actual service)
docker compose logs <service-name>
docker compose logs postgresql-service
docker compose logs ui-gateway

# Check container health status
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}"

# Check system resources
docker stats --no-stream

# Check disk space
df -h

# Check Docker disk usage
docker system df
```

---

## Container Health Checks Failing

### Symptom
Containers showing "unhealthy" status or failing to start completely.

```bash
$ docker compose ps
NAME                    STATUS
adempiere-ui-gateway.opensearch    Up 2 minutes (unhealthy)
adempiere-ui-gateway.kafka         Up 90 seconds (unhealthy)
```

### Common Causes

#### 1. Normal Startup Times (NOT an error!)

**Java-based services take 60-120 seconds to start** - this is normal and expected.

| Service | Normal Startup Time | Health Check Tolerance |
|---------|--------------------|-----------------------|
| OpenSearch | 60-120 seconds | Up to 5 minutes |
| Kafka | 60-90 seconds | Up to 4 minutes |
| PostgreSQL | 10-30 seconds | Up to 3 minutes |
| ADempiere ZK | 30-60 seconds | Up to 3 minutes |

Solution: Wait 2-3 minutes after running `docker compose up`, then check status again.

```bash
# Wait 2 minutes, then check
sleep 120
docker compose ps
```

If containers are still "starting" after 5 minutes, then investigate further.

#### 2. Insufficient Memory

- Containers repeatedly restarting
- "OOMKilled" in container status
- Java heap space errors in logs

```bash
# Check if containers were killed due to memory
docker compose ps -a | grep -i "oom"

# Check container logs for memory errors
docker compose logs opensearch-node | grep -i "memory\|heap"
```

- Increase host RAM (minimum 8 GB, recommended 16 GB)
- Reduce services using specific profiles instead of `all`
- Configure memory limits in docker-compose.yml

#### 3. Port Conflicts

- Container fails to start
- Error: "port is already allocated"

```bash
# Check what's using port 80 (nginx)
sudo lsof -i :80

# Check PostgreSQL port
sudo lsof -i :55432
```

- Stop the conflicting service
- Or change the port in `env_template.env`

```bash
# Edit env_template.env
nano env_template.env

# Change port (example for PostgreSQL)
POSTGRES_EXTERNAL_PORT="55433"  # Changed from 55432

# Restart stack
./stop-all.sh
./start-all.sh
```

#### 4. Database Initialization Failed

- PostgreSQL unhealthy
- Other services waiting for database
- "database does not exist" errors

```bash
docker compose logs postgresql-service | grep -i "error\|failed"
```

Solution: See [Database Issues](#database-issues) section below.

---

## Database Issues

### Database Won't Restore

- PostgreSQL starts but database is empty
- No ADempiere data
- Login fails


#### 1. Database Directory Already Exists

The restore only happens if `postgresql/postgres_database/` is empty.

```bash
ls -la postgresql/postgres_database/
```

Solution: Delete the database directory and restart:

```bash
# Stop containers
./stop-all.sh

# Delete database (CAUTION: This deletes all data!)
sudo rm -rf postgresql/postgres_database/*

# Restart - restore will happen automatically
./start-all.sh
```

#### 2. Seed File Not Found

```bash
ls -la postgresql/postgres_backups/seed.backup
```

Solution: Place a valid backup file:

```bash
# Copy your backup file
cp /path/to/your/backup.backup postgresql/postgres_backups/seed.backup

# Or download from GitHub (latest ADempiere seed)
# The script will do this automatically if no seed.backup exists
```

#### 3. Restore File Corrupted

```bash
docker compose logs postgresql-service | grep -i "restore\|pg_restore"
```

Solution: Get a fresh backup file and try again.

### Database Connection Refused

- Services can't connect to database
- Error: "connection refused" or "could not connect to server"

```bash
# Check if PostgreSQL is running
docker compose ps postgresql-service

# Check PostgreSQL logs
docker compose logs postgresql-service

# Try connecting from host
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -d adempiere -c "SELECT version();"
```

- Wait for PostgreSQL to fully start (30 seconds)
- Check health status: `docker compose ps`
- Verify credentials in `env_template.env`

### Database Already Exists (No Restore Happening)

You want a fresh restore, but the database already exists and restore is skipped.


```bash
# Stop all containers
./stop-all.sh

# Delete the database
sudo rm -rf postgresql/postgres_database/*

# Ensure seed.backup exists
ls -la postgresql/postgres_backups/seed.backup

# Restart - restore will execute
./start-all.sh

# Monitor the restore process
docker compose logs -f postgresql-service
```

---

## Timezone Mismatches

### Symptoms
- Container times don't match host time
- Logs show wrong timestamps
- Scheduled jobs run at wrong times

### Diagnosis

Use the diagnostic scripts provided in `docs/scripts/` to check timezone synchronization:

```bash
# Run from repository root or docs/scripts/ directory
cd docs/scripts/

# Check for any time mismatches (>2 seconds difference)
./01-contaniner-times-mismatches.sh

# View detailed timezone configuration for all containers
./02-container-times-detailed.sh

# Simple view of all container times
./03-all-container-times-simple.sh
```

**See also:** Diagnostic Scripts README (TODO: not yet available) for detailed usage information.

Expected output:
- All containers should show `Time diff: 0s (OK)`
- All containers should have `TZ env var` set to same timezone (e.g., `Europe/Berlin`, `America/New_York`, etc.)

### Common Issues

#### 1. TZ Environment Variable Not Set

```
Container: adempiere-ui-gateway.site
  TZ env var: not set
  Date: Fri Feb 13 14:55:24 UTC 2026
```

Solution: Add TZ to the service in `docker-compose.yml`:

```yaml
service-name:
  environment:
    TZ: ${GENERIC_TIMEZONE}
```

Then recreate the container:

```bash
cd docker-compose/
docker compose stop service-name
docker compose rm -f service-name
docker compose up -d service-name
```

**Important:** Environment variables are set at container creation, not runtime. You must **recreate** the container (not just restart) for TZ changes to take effect.

#### 2. Time Displays UTC Despite TZ Variable

```
Container: adempiere-ui-gateway.s3-storage
  Date: Fri Feb 13 14:41:53 UTC 2026  (displays UTC despite TZ setting)
  TZ env var: Europe/Berlin
```

Cause: Some containers' `date` command doesn't properly respect the TZ environment variable.

```bash
# Check if container has timezone data (example: Europe)
docker exec adempiere-ui-gateway.s3-storage ls -la /usr/share/zoneinfo/Europe/

# Check /etc/localtime
docker exec adempiere-ui-gateway.s3-storage ls -la /etc/localtime
```

Solution: Container may need timezone data mounted or installed. This is usually cosmetic (timestamps are still correct, just displayed in UTC).

#### 3. Containers Created Before TZ Configuration

Symptom: Old containers don't have TZ set, new ones do.

Solution: Recreate all containers:

```bash
cd docker-compose/
./stop-all.sh
./start-all.sh
```

### Understanding Timezone Configuration

The TZ environment variable **overrides** file-based timezone settings:

Priority (highest to lowest):
1. `TZ` environment variable (preferred method)
2. `/etc/localtime` symlink
3. `/etc/timezone` file

Why times show as synchronized even with different timezones:
- Unix timestamps are always UTC internally
- Display timezone (TZ variable) only affects how time is formatted
- Time difference = 0s means clocks are synchronized (correct)
- Different display formats are cosmetic

---

## Container Start/Stop Issues

### Containers Won't Start

#### 1. Dependency Issues

```
adempiere-ui-gateway.vue-ui        Exited (1)
Depends on: adempiere-grpc-server (not healthy yet)
```

Solution: Dependencies require health checks to pass. Wait for dependent services:

```bash
# Check which services are healthy
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}"

# Wait and check again after 2 minutes
sleep 120
docker compose ps
```

If dependencies never become healthy, check their logs:

```bash
docker compose logs adempiere-grpc-server
```

#### 2. Previous Container Not Removed

```
Error: Conflict. The container name "/adempiere-ui-gateway.zk" is already in use
```


```bash
# Remove old containers
docker compose down

# Or force remove specific container
docker rm -f adempiere-ui-gateway.zk

# Recreate
docker compose up -d
```

#### 3. Image Pull Failed

```
Error: pull access denied for openls/dictionary-rs, repository does not exist
```

- Check internet connection
- Verify image name in `env_template.env`
- Check if image exists on Docker Hub
- Try manual pull: `docker pull <image-name>:<tag>`

### Containers Keep Restarting

```bash
docker compose ps -a
```

Check why it's failing:
```bash
docker compose logs <service-name> --tail 100
```

- Missing environment variables
- Failed health checks (see above)
- Application crashes (check logs)
- Resource limits exceeded

---

## Network and Access Issues

### Can't Access Application (Port 80)

- Browser shows "connection refused" or "site can't be reached"
- URL: `http://<HOST_IP>/` doesn't work


```bash
# 1. Check if nginx is running
docker compose ps ui-gateway

# 2. Check if port 80 is listening
sudo netstat -tlnp | grep :80
# or
sudo lsof -i :80

# 3. Check nginx logs
docker compose logs ui-gateway

# 4. Test from within host
curl http://localhost/
```


#### 1. nginx Not Running

```bash
docker compose up -d ui-gateway
docker compose logs ui-gateway
```

#### 2. Firewall Blocking Port 80

```bash
# Check if firewall is active
sudo ufw status
sudo firewall-cmd --list-all  # RHEL/CentOS

# Allow port 80
sudo ufw allow 80/tcp
sudo firewall-cmd --add-port=80/tcp --permanent  # RHEL/CentOS
sudo firewall-cmd --reload  # RHEL/CentOS
```

**Remember:** Docker bypasses host firewall (UFW, firewalld). You need an external firewall for true security.

#### 3. Wrong HOST_IP in Configuration

```bash
grep HOST_IP docker-compose/env_template.env
```

```bash
nano docker-compose/env_template.env
# Set HOST_IP to your actual IP or domain
HOST_IP=192.168.1.100

# Restart
./stop-all.sh
./start-all.sh
```

### Can't Access ZK UI or Vue UI

```bash
curl http://<HOST_IP>/webui
curl http://<HOST_IP>/vue
```

```bash
docker exec adempiere-ui-gateway.nginx-ui-gateway cat /etc/nginx/conf.d/api_gateway.conf
```

```bash
docker compose ps adempiere-zk
docker compose ps vue-ui
```

### Internal Container Communication Issues

Symptom: Services can't reach each other (e.g., Vue can't connect to gRPC backend)

```bash
# List networks
docker network ls

# Inspect the adempiere network
docker network inspect adempiere-ui-gateway.network

# Check if containers are on same network
docker inspect adempiere-ui-gateway.vue-ui | grep NetworkMode
docker inspect adempiere-ui-gateway.adempiere-grpc-server | grep NetworkMode
```

```bash
# From vue-ui to grpc-server
docker exec adempiere-ui-gateway.vue-ui ping adempiere-grpc-server

# From any container to postgres
docker exec adempiere-ui-gateway.vue-ui nc -zv postgresql-service 5432
```

---

## Performance Issues

### Slow Startup Times

- Total stack: 90-120 seconds
- OpenSearch: 60-120 seconds (Java initialization)
- Kafka: 60-90 seconds (Java initialization)

If slower than 5 minutes:

```bash
# Monitor container resource usage
docker stats

# Check host resources
htop  # or top
df -h  # disk space
```

1. **Use SSD instead of HDD** - 5-10x faster
2. **Increase RAM** - Less disk I/O
3. **Close other applications** - Free up resources
4. **Check disk I/O**: `iostat -x 1`

### Slow Application Response


```bash
# Check container CPU/memory usage
docker stats --no-stream

# Check host CPU
top

# Check PostgreSQL performance
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -d adempiere -c "
  SELECT pid, now() - pg_stat_activity.query_start AS duration, query
  FROM pg_stat_activity
  WHERE state = 'active'
  ORDER BY duration DESC;
"
```


#### 1. PostgreSQL Needs Maintenance

```bash
# Vacuum and analyze database
docker exec adempiere-ui-gateway.postgresql vacuumdb -U postgres -d adempiere -v -z

# Reindex
docker exec adempiere-ui-gateway.postgresql reindexdb -U postgres -d adempiere -v
```

#### 2. Insufficient Resources

- Upgrade to larger instance (see [System Requirements](./system-requirements.md))
- Add more RAM
- Use faster CPU

#### 3. Network Latency

```bash
# Test latency from client to server
ping <HOST_IP>

# Test from container to database
docker exec adempiere-ui-gateway.vue-ui time nc -zv postgresql-service 5432
```

### High CPU or Memory Usage


```bash
docker stats --no-stream | sort -k3 -h  # Sort by CPU
docker stats --no-stream | sort -k4 -h  # Sort by memory
```

- **OpenSearch** - Normal to use 2-4 GB
- **PostgreSQL** - Large queries or missing indexes
- **Java services** - Normal high startup CPU, should stabilize

- Add more RAM
- Optimize database queries
- Review application logs for errors causing retry loops

---

## Disk Space Issues

### Out of Disk Space

- Container won't start
- Database restore fails
- Error: "no space left on device"

```bash
# Check overall disk space
df -h

# Check Docker-specific usage
docker system df

# Detailed breakdown
docker system df -v
```


#### 1. Clean Docker Cache

```bash
# Remove unused images, containers, networks
docker system prune -a

# Remove volumes (CAUTION: This deletes data!)
docker system prune -a --volumes
```

#### 2. Remove Old Images

```bash
# List images
docker images -a

# Remove specific image
docker rmi <image-id>

# Remove all unused images
docker image prune -a
```

#### 3. Clean PostgreSQL Backups

```bash
# Check backup directory size
du -sh postgresql/postgres_backups/

# Remove old backups (keep only recent ones)
cd postgresql/postgres_backups/
ls -lht  # List by date
rm old-backup-file.backup
```

#### 4. Expand Disk

If cleaning doesn't help, you need more disk space:
- Expand VM disk
- Add new volume and move Docker data
- Move database to larger partition

---

## Common Error Messages

### "driver failed programming external connectivity"

Full error:
```
Error response from daemon: driver failed programming external connectivity
on endpoint adempiere-ui-gateway.nginx-ui-gateway:
Error starting userland proxy: listen tcp4 0.0.0.0:80: bind: address already in use
```

Cause: Port 80 already in use by another service.

```bash
# Find what's using port 80
sudo lsof -i :80

# Stop that service (example: Apache)
sudo systemctl stop apache2

# Or change nginx port in env_template.env
```

### "connection refused" to PostgreSQL

Error in logs:
```
connection refused: could not connect to server: Connection refused
Is the server running on host "postgresql-service" and accepting TCP/IP connections on port 5432?
```

Cause: PostgreSQL not ready yet, or not running.

```bash
# Check PostgreSQL status
docker compose ps postgresql-service

# Wait for it to be healthy
docker compose ps --format "table {{.Name}}\t{{.Health}}"

# Check logs
docker compose logs postgresql-service
```

### "unhealthy" Status Persists

If container shows unhealthy for >5 minutes:

```bash
# Check health check configuration
docker inspect adempiere-ui-gateway.opensearch | grep -A 10 Healthcheck

# Check what the health check is doing
docker exec adempiere-ui-gateway.opensearch <health-check-command>

# Example for OpenSearch:
docker exec adempiere-ui-gateway.opensearch bash -c 'printf "GET / HTTP/1.1\n\n" > /dev/tcp/127.0.0.1/9200; exit $?;'
```

### "no such file or directory" - seed.backup

Error:
```
pg_restore: error: could not open input file "/home/adempiere/postgres_backups/seed.backup": No such file or directory
```

```bash
# Check if backup file exists
ls -la postgresql/postgres_backups/

# If missing, add a backup file
cp /path/to/backup.backup postgresql/postgres_backups/seed.backup

# Or let the script download from GitHub automatically
# (just ensure the file is named correctly)
```

---

## POS Application Errors

### ScriptEngine NullPointerException (Groovy AD_Rules)

#### Symptom

When processing a POS order (clicking the cart/process button), the operation fails with:

```
java.lang.NullPointerException: Cannot invoke "javax.script.ScriptEngine.put(String, Object)" because "engine" is null
```

Full stack trace from container `adempiere-ui-gateway.vue-grpc-server` (check with `docker logs adempiere-ui-gateway.vue-grpc-server`):

```
org.compiere.model.MRule.setContext(MRule.java:240)
org.compiere.model.ModelValidationEngine.lambda$fireDocValidate$17(ModelValidationEngine.java:501)
org.compiere.model.MOrder.completeIt(MOrder.java:1810)
org.spin.pos.service.order.OrderManagement.processOrder(OrderManagement.java:111)
org.spin.grpc.service.PointOfSalesForm.processOrder(PointOfSalesForm.java:3684)
```

#### Containers Involved

The request travels through this chain when a POS order is processed:

```
Browser → nginx (adempiere-ui-gateway.nginx-ui-gateway)
        → Envoy proxy (adempiere-ui-gateway.envoy-grpc-proxy)  [HTTP/JSON ↔ gRPC transcoding]
        → gRPC server (adempiere-ui-gateway.vue-grpc-server)   ← error occurs here
              ↕
        PostgreSQL (adempiere-ui-gateway.postgresql)            [stores the AD_Rule script]
```

The gRPC server calls `MOrder.completeIt()`, which triggers `ModelValidationEngine.fireDocValidate()`. This fires any active `AD_Rule` records of type Script/Document. If any rule has a `groovy:` prefix (e.g., `groovy:OrderQtyOnHand`), ADempiere requests a `groovy` ScriptEngine via the JSR-223 API — and if Groovy is not on the classpath, the engine is `null`, causing the NPE.

#### Root Cause

Java 17 removed the built-in Nashorn JavaScript engine and never included a Groovy engine. The gRPC server image's startup script (`start-backend.sh`) uses a **hard-coded explicit classpath** generated by Gradle at build time — it does not use a wildcard. Therefore, simply placing Groovy JARs in `lib/` is not enough; they must also be registered in the classpath.

#### Diagnosis

```bash
# 1. Confirm the error in the gRPC server logs
docker logs adempiere-ui-gateway.vue-grpc-server 2>&1 | grep -A 3 "ScriptEngine\|MRule"

# 2. Check whether Groovy JARs are on the classpath
docker exec adempiere-ui-gateway.vue-grpc-server \
    grep "groovy" /opt/apps/server/bin/start-backend.sh

# 3. Check which AD_Rules with "groovy:" prefix are active in the database
docker exec adempiere-ui-gateway.postgresql \
    psql -U adempiere -d adempiere -c \
    "SELECT ad_rule_id, name, ruletype, eventtype FROM ad_rule WHERE name LIKE 'groovy:%' AND isactive = 'Y';"
```

If step 2 returns nothing, Groovy is not on the classpath — this is the cause.

#### Immediate Fix (no image rebuild)

Use this to fix a running container without rebuilding the image. The fix is lost if the container is recreated.

```bash
# Step 1: Download Groovy JARs to the host
cd /tmp
wget -q https://repo1.maven.org/maven2/org/codehaus/groovy/groovy/3.0.22/groovy-3.0.22.jar
wget -q https://repo1.maven.org/maven2/org/codehaus/groovy/groovy-jsr223/3.0.22/groovy-jsr223-3.0.22.jar

# Step 2: Copy JARs into the container
docker cp /tmp/groovy-3.0.22.jar        adempiere-ui-gateway.vue-grpc-server:/opt/apps/server/lib/
docker cp /tmp/groovy-jsr223-3.0.22.jar adempiere-ui-gateway.vue-grpc-server:/opt/apps/server/lib/
docker exec -u root adempiere-ui-gateway.vue-grpc-server \
    chown adempiere:adempiere \
        /opt/apps/server/lib/groovy-3.0.22.jar \
        /opt/apps/server/lib/groovy-jsr223-3.0.22.jar

# Step 3: Create a script to patch the classpath in start-backend.sh
printf '%s\n' '#!/bin/sh' \
  'sed -i '"'"'/^CLASSPATH=.*adempiere-grpc-server/a CLASSPATH="$CLASSPATH:$APP_HOME/lib/groovy-3.0.22.jar:$APP_HOME/lib/groovy-jsr223-3.0.22.jar"'"'"' /opt/apps/server/bin/start-backend.sh' \
  > /tmp/fix_classpath.sh

docker cp /tmp/fix_classpath.sh adempiere-ui-gateway.vue-grpc-server:/tmp/
docker exec -u root adempiere-ui-gateway.vue-grpc-server sh /tmp/fix_classpath.sh

# Step 4: Verify the classpath was patched (should return 1)
docker exec adempiere-ui-gateway.vue-grpc-server \
    grep -c "groovy" /opt/apps/server/bin/start-backend.sh

# Step 5: Restart the gRPC server to apply the change
cd docker-compose/
docker compose restart adempiere-grpc-server
```

#### Permanent Fix (build a new image)

Create a `Dockerfile.grpc-server-groovyfix` in `docker-compose/` with the following content. It adds the Groovy JARs and patches the classpath at image-build time.

```dockerfile
# Replace the FROM line with VUE_GRPC_SERVER_IMAGE:VUE_BACKEND_GRPC_SERVER_VERSION from env_template.env
FROM <image>:<version>

USER root

RUN cd /opt/apps/server/lib && \
    wget -q https://repo1.maven.org/maven2/org/codehaus/groovy/groovy/3.0.22/groovy-3.0.22.jar && \
    wget -q https://repo1.maven.org/maven2/org/codehaus/groovy/groovy-jsr223/3.0.22/groovy-jsr223-3.0.22.jar && \
    chown adempiere:adempiere groovy-3.0.22.jar groovy-jsr223-3.0.22.jar && \
    sed -i '/^CLASSPATH=.*adempiere-grpc-server/a CLASSPATH="$CLASSPATH:$APP_HOME/lib/groovy-3.0.22.jar:$APP_HOME/lib/groovy-jsr223-3.0.22.jar"' \
        /opt/apps/server/bin/start-backend.sh

USER adempiere
```

Then build and deploy:

```bash
cd docker-compose/

# Build the fixed image
docker build \
    -f Dockerfile.grpc-server-groovyfix \
    -t <image>:<version>-groovyfix \
    .

# Update env_template.env to use the new image
# Change VUE_BACKEND_GRPC_SERVER_VERSION from "<version>" to "<version>-groovyfix"
nano env_template.env
cp env_template.env .env

# Recreate the gRPC server container with the new image
docker compose up -d --no-deps adempiere-grpc-server
```

#### Why Two JARs Are Needed

| JAR | Purpose |
|-----|---------|
| `groovy-3.0.22.jar` | Core Groovy runtime (language, compiler, standard library) |
| `groovy-jsr223-3.0.22.jar` | Registers `"groovy"` as a JSR-223 `ScriptEngine` name via `ServiceLoader` |

Both are required. Without `groovy-jsr223`, the engine lookup returns `null` even with the core JAR present.

---

## Getting Help

If you've tried the solutions above and still have issues:

1. **Check logs thoroughly:**
   ```bash
   docker compose logs <service-name> > service-logs.txt
   ```

2. **Gather diagnostic information:**
   ```bash
   # System info
   docker version
   docker compose version
   uname -a

   # Resource info
   df -h
   free -h

   # Container status
   docker compose ps -a
   docker stats --no-stream
   ```

3. **Trace the error through the stack:** See [Debugging Vue Frontend](./debugging-vue-frontend.md) for a step-by-step guide to following an error from the browser through nginx, Envoy, and the gRPC server.

4. **Check GitHub issues:** [ADempiere UI Gateway Issues](https://github.com/adempiere/adempiere-ui-gateway/issues)

4. **Search ADempiere community forums**

5. **Create a new issue** with:
   - Error message (full text)
   - Relevant logs
   - System information
   - Steps to reproduce

---

## Prevention Tips

**Avoid common issues:**

1. ✅ **Meet system requirements** - See [System Requirements](./system-requirements.md)
2. ✅ **Use SSD for production** - Much faster than HDD
3. ✅ **Monitor disk space** - Keep 30% free
4. ✅ **Regular database maintenance** - Weekly VACUUM
5. ✅ **Keep backups** - Multiple copies, tested restores
6. ✅ **External firewall** - Don't rely on host firewall
7. ✅ **Review logs regularly** - Catch issues early
8. ✅ **Test in development first** - Before production changes
9. ✅ **Document customizations** - Know what you changed
10. ✅ **Update gradually** - Test updates before deploying

---

[Back to README](../README.md) | [Previous: Debugging Vue Frontend](./debugging-vue-frontend.md) | [Next: Additional Info](./additional_info.md)

