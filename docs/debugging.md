# Debugging Guide

This guide provides comprehensive debugging commands and techniques for troubleshooting the ADempiere UI Gateway stack.

For common problems and their solutions, see the [Troubleshooting Guide](./troubleshooting.md).

## Table of Contents

- [Prerequisites](#prerequisites)
- [Basic Operations](#basic-operations)
- [Service Management](#service-management)
- [Viewing Logs](#viewing-logs)
- [Container Inspection](#container-inspection)
- [Resource Monitoring](#resource-monitoring)
- [Network Debugging](#network-debugging)
- [Database Operations](#database-operations)
- [Advanced Debugging](#advanced-debugging)
- [Utility Scripts](#utility-scripts)
- [Common Debugging Scenarios](#common-debugging-scenarios)
- [Additional Resources](#additional-resources)

---

## Prerequisites

**About sudo:**
- Commands shown **without** `sudo` for clarity
- Add `sudo` before commands if your Docker installation requires it
- Test with: `docker ps` (if this fails, use `sudo docker ps`)

**Working Directory:**
All commands assume you're in the `docker-compose/` directory unless specified otherwise.

```bash
cd docker-compose/
```

---

## Basic Operations

### View Running Containers

```bash
# List all containers (running and stopped)
docker compose ps -a

# Show only running containers
docker compose ps

# Show container IDs and names
docker compose ps -a --format "{{.ID}}: {{.Names}}"

# Show all Docker containers (not just this stack)
docker ps -a
docker ps -a --format "{{.ID}}: {{.Names}}"
```

### View Available Services

```bash
# List all services defined in docker-compose.yml
docker compose config --services

# Note: run this from the docker-compose/ directory, where the
# committed docker-compose.yml lives (it is static, not generated)
```

### View Docker Images

```bash
# List all Docker images on the system
docker images -a

# List images for this stack only
docker images | grep adempiere
docker images | grep openls
```

### Check Stack Health

```bash
# Quick health overview
docker compose ps

# Look for:
# - Status: "Up (healthy)" = good
# - Status: "Up (unhealthy)" = service running but health check failing
# - Status: "Exited" = service crashed or stopped
```

For detailed health check information, see [Architecture - Health Checks](./architecture.md#health-checks-and-startup-order).

---

## Service Management

### Start/Stop Individual Services

```bash
# Start a single service (if stopped)
docker compose start <service-name>
docker compose start adempiere-site
docker compose start postgresql-service

# Stop a single service (keeps container)
docker compose stop <service-name>
docker compose stop adempiere-zk

# Restart a single service
docker compose restart <service-name>
docker compose restart nginx-ui-gateway
```

### Recreate Services

```bash
# Stop and remove a single service
docker compose rm -s -f <service-name>
docker compose rm -s -f postgresql-service

# Recreate the service
docker compose up -d <service-name>

# Example: Recreate ZK UI container
docker compose stop adempiere-zk
docker compose rm -f adempiere-zk
docker compose up -d adempiere-zk
```

**When to recreate:**
- After changing environment variables in `env_template.env`
- After modifying docker-compose service definitions
- When container is in a broken state

**Note:** Restarting (`docker compose restart`) does NOT apply environment variable changes. You must recreate the container.

### Stop Entire Stack

```bash
# Stop all containers (preserves containers, volumes, networks)
docker compose stop

# Stop and remove containers (preserves volumes and data)
docker compose down

# ./stop-all.sh              → docker compose down + removes .env (keeps volumes/data)
# ./stop-and-delete-all.sh   → complete/destructive cleanup (also deletes volumes and images)
```

### Recreate All Services

```bash
# Stop all services
docker compose down

# Start all services
docker compose up -d
```

---

## Viewing Logs

### Container Logs

```bash
# View logs for a specific container
docker container logs <container-name>

# Examples (use container names, not service names):
docker container logs adempiere-ui-gateway.postgresql
docker container logs adempiere-ui-gateway.zk
docker container logs adempiere-ui-gateway.nginx-ui-gateway
docker container logs adempiere-ui-gateway.grpc-server

# Paginate logs with less
docker container logs adempiere-ui-gateway.postgresql | less

# Follow logs in real-time (like tail -f)
docker container logs -f adempiere-ui-gateway.grpc-server

# Show only last 100 lines
docker container logs --tail 100 adempiere-ui-gateway.kafka

# Show logs with timestamps
docker container logs -t adempiere-ui-gateway.zk
```

### Common Log Locations

Different services log to different places:

```bash
# PostgreSQL logs
docker container logs adempiere-ui-gateway.postgresql

# ZK UI logs (application logs)
docker exec adempiere-ui-gateway.zk cat /opt/apps/adempiere/logs/adempiere.log

# nginx access and error logs
docker container logs adempiere-ui-gateway.nginx-ui-gateway

# gRPC server logs
docker container logs adempiere-ui-gateway.grpc-server
```

### Search Logs for Errors

```bash
# Search for errors in logs
docker container logs adempiere-ui-gateway.grpc-server 2>&1 | grep -i error

# Search for specific text
docker container logs adempiere-ui-gateway.zk 2>&1 | grep -i "connection refused"

# Find stack traces
docker container logs adempiere-ui-gateway.grpc-server 2>&1 | grep -A 20 "Exception"
```

---

## Container Inspection

### Display Container Configuration

```bash
# Show full container configuration
docker container inspect <container-name>

# Examples:
docker container inspect adempiere-ui-gateway.postgresql
docker container inspect adempiere-ui-gateway.zk

# Extract specific information with --format
docker container inspect --format='{{.State.Health.Status}}' adempiere-ui-gateway.postgresql
docker container inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' adempiere-ui-gateway.zk
docker container inspect --format='{{.Config.Env}}' adempiere-ui-gateway.grpc-server
```

### View Merged Docker Compose Configuration

Renders the actual configuration that will be applied to Docker. Run this while the stack is running (so `.env` exists):

```bash
# View merged configuration (stack must be running, or .env must exist)
docker compose convert

# This shows:
# - Resolved environment variables
# - Actual values that will be used
# - Network configurations
# - Volume mounts
```

**Use this to:**
- Debug environment variable substitution
- Verify configuration before starting stack
- Check which ports are exposed
- Confirm volume mount paths

**Note:** `.env` is generated automatically by `start-all.sh`. It exists while the stack is running and is deleted by `stop-all.sh`. Do not create it manually.

---

## Resource Monitoring

### Real-Time Resource Usage

```bash
# Show CPU, memory, network, disk I/O for all containers
docker stats

# Show stats for specific container
docker stats adempiere-ui-gateway.postgresql

# Show stats once (no continuous update)
docker stats --no-stream

# Show all containers including stopped ones
docker stats -a
```

**What to look for:**
- **CPU %**: Java services (ZK, gRPC) may use 50-100% during startup, should stabilize < 20%
- **Memory Usage**: Check against limits (see [System Requirements](./system-requirements.md))
- **Network I/O**: High traffic to database indicates query performance issues
- **Block I/O**: High disk I/O may indicate database performance bottleneck

### Disk Space Usage

```bash
# Show Docker disk usage summary
docker system df

# Detailed view
docker system df -v

# Check specific volume sizes
docker volume ls
docker volume inspect adempiere-ui-gateway.volume_postgres
```

### Container Process List

```bash
# Show running processes inside a container
docker top <container-name>

# Examples:
docker top adempiere-ui-gateway.postgresql
docker top adempiere-ui-gateway.zk

# Useful for:
# - Checking if Java processes are running
# - Finding process IDs for debugging
# - Verifying services started inside container
```

---

## Network Debugging

### Container Network Information

```bash
# List Docker networks
docker network ls

# Inspect the stack's network
docker network inspect adempiere-ui-gateway.adempiere_network

# Show container IP addresses
docker compose ps -a --format "{{.Name}}: {{.Ports}}"

# Get specific container IP
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' adempiere-ui-gateway.postgresql
```

### Test Network Connectivity

```bash
# Test connectivity between containers
docker exec adempiere-ui-gateway.zk ping -c 3 adempiere-ui-gateway.postgresql

# Test DNS resolution
docker exec adempiere-ui-gateway.zk nslookup postgresql

# Test port connectivity
docker exec adempiere-ui-gateway.zk nc -zv postgresql 5432

# Test HTTP endpoint
docker exec adempiere-ui-gateway.zk wget -O- http://nginx-ui-gateway:80
```

### Check Port Exposure

```bash
# Show which ports are exposed to host
docker compose ps --format "{{.Name}}: {{.Ports}}"

# Check if port is listening on host
netstat -tuln | grep 80
netstat -tuln | grep 55432

# Test external access
curl http://localhost:80
curl http://localhost:19000  # Kafdrop
```

---

## Database Operations

### Database Connection Testing

```bash
# List databases
docker exec adempiere-ui-gateway.postgresql psql -U postgres -l

# Connect to database
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -d adempiere

# Test connection from another container
docker exec adempiere-ui-gateway.zk psql -h postgresql -U postgres -d adempiere -c "SELECT version();"
```

### Database Query Testing

```bash
# Quick query from outside container
docker exec adempiere-ui-gateway.postgresql \
  psql -U adempiere -d adempiere -c "SELECT COUNT(*) FROM ad_table;"

# Check table exists
docker exec adempiere-ui-gateway.postgresql \
  psql -U adempiere -d adempiere -t \
  -c "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'ad_user');"

# Check search_path
docker exec adempiere-ui-gateway.postgresql \
  psql -U adempiere -d adempiere -c "SHOW search_path;"
```

### Database Backup and Restore

**For complete backup/restore procedures, see [Backup and Restore Guide](./backup-restore.md).**

Quick reference:

```bash
# Create backup
docker exec -i adempiere-ui-gateway.postgresql \
  pg_dump --no-owner -h localhost -U postgres adempiere \
  > postgresql/postgres_backups/adempiere-$(date '+%Y-%m-%d').backup

# Restore database
docker exec -i adempiere-ui-gateway.postgresql \
  psql -U adempiere -d adempiere \
  < postgresql/postgres_backups/<your-backup-file>.backup

# Automated backup script (lives in docs/scripts/, run from the repo root)
cd ..
./docs/scripts/04-backup-database.sh
```

### Database Deletion (Advanced)

⚠️ **WARNING**: These operations are destructive and irreversible!

**Always create a backup first.** See [Backup Guide](./backup-restore.md#quick-backup-procedure).

**Method 1: Delete via mounted volume (recommended)**

```bash
# Navigate to repository root
cd /path/to/adempiere-ui-gateway_SHW

# Verify path before deletion!
ls -al docker-compose/postgresql/postgres_database/

# Delete database files
sudo rm -rf docker-compose/postgresql/postgres_database/*

# Restart stack to trigger automatic restore from seed.backup
cd docker-compose/
./stop-all.sh
./start-all.sh
```

**Method 2: Delete via Docker volume**

```bash
# View volume location
docker volume inspect adempiere-ui-gateway.volume_postgres

# Delete volume data
sudo rm -rf /var/lib/docker/volumes/adempiere-ui-gateway.volume_postgres/_data/*
```

**Method 3: Drop database (preserves data files)**

```bash
# Drop and recreate database
docker exec -it adempiere-ui-gateway.postgresql \
  psql -U postgres -c "DROP DATABASE adempiere WITH (FORCE);"

docker exec -it adempiere-ui-gateway.postgresql \
  psql -U postgres -c "CREATE DATABASE adempiere WITH OWNER=adempiere;"

# Restore from backup
docker exec -i adempiere-ui-gateway.postgresql \
  psql -U adempiere -d adempiere \
  < postgresql/postgres_backups/<your-backup-file>.backup
```

---

## Advanced Debugging

### Execute Commands Inside Containers

```bash
# Run a single command
docker container exec -it <container-name> <command>

# Examples:
docker container exec -it adempiere-ui-gateway.postgresql date
docker container exec -it adempiere-ui-gateway.zk ls -la /opt/apps
docker container exec -it adempiere-ui-gateway.nginx-ui-gateway nginx -t
```

### Interactive Shell Access

```bash
# Access container shell (bash)
docker container exec -it <container-name> bash

# Examples:
docker container exec -it adempiere-ui-gateway.postgresql bash
docker container exec -it adempiere-ui-gateway.zk bash
docker container exec -it adempiere-ui-gateway.nginx-ui-gateway bash

# Some containers use sh instead of bash
docker container exec -it adempiere-ui-gateway.opensearch sh
docker container exec -it adempiere-ui-gateway.kafka sh
```

**Once inside container:**

```bash
# PostgreSQL container
psql -U postgres -d adempiere
psql -U postgres -l
tail -f /var/lib/postgresql/data/log/postgresql.log

# ZK container
cd /opt/apps/adempiere/logs
tail -f adempiere.log
ls -la /opt/Persistent_Context

# nginx container
nginx -t                    # Test configuration
cat /var/log/nginx/error.log
cat /var/log/nginx/access.log

# Exit container
exit
```

### File Operations

```bash
# Copy file from container to host
docker cp adempiere-ui-gateway.zk:/opt/apps/adempiere/logs/adempiere.log ./zk-debug.log

# Copy file from host to container
docker cp ./custom-config.xml adempiere-ui-gateway.zk:/opt/apps/config/

# View file contents without copying
docker exec adempiere-ui-gateway.zk cat /opt/apps/adempiere/logs/adempiere.log

# Edit file in container (if vi/nano installed)
docker exec -it adempiere-ui-gateway.postgresql vi /var/lib/postgresql/data/postgresql.conf
```

### Environment Variables

```bash
# Show all environment variables in a container
docker exec <container-name> env

# Examples:
docker exec adempiere-ui-gateway.postgresql env | grep POSTGRES
docker exec adempiere-ui-gateway.zk env | grep ADEMPIERE
docker exec adempiere-ui-gateway.nginx-ui-gateway env | grep TZ

# Check specific variable
docker exec adempiere-ui-gateway.postgresql printenv POSTGRES_PASSWORD
```

### Health Check Debugging

```bash
# View health status
docker inspect --format='{{.State.Health.Status}}' adempiere-ui-gateway.postgresql

# View last health check log
docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' adempiere-ui-gateway.grpc-server

# Manually run health check command
docker exec adempiere-ui-gateway.postgresql pg_isready -U postgres
```

For expected health check timings, see [Architecture - Health Checks](./architecture.md#health-checks-and-startup-order).

---

## Utility Scripts

The project includes diagnostic scripts in `docs/scripts/` for common debugging tasks. Unlike the rest of this guide, run these from the **repository root** (not `docker-compose/`) — the `./docs/scripts/...` paths below are relative to it.

### Timezone Diagnostic Scripts

```bash
# Quick check for time synchronization issues
./docs/scripts/01-contaniner-times-mismatches.sh

# Detailed timezone configuration report
./docs/scripts/02-container-times-detailed.sh

# Simple table view of all container times
./docs/scripts/03-all-container-times-simple.sh
```

See [Scripts README](./scripts/README.md) for complete documentation.

### Database Backup Script

```bash
# Automated backup with compression and retention
./docs/scripts/04-backup-database.sh [backup-directory]
```

See [Backup and Restore Guide](./backup-restore.md) for complete documentation.

---

## Common Debugging Scenarios

### Service Won't Start

**Symptoms:**
- Container immediately exits
- Health check fails repeatedly
- Stack hangs during startup

**Debug steps:**

1. **Check logs:**
   ```bash
   docker container logs <container-name>
   ```

2. **Check dependencies:**
   ```bash
   # Verify PostgreSQL is running first
   docker compose ps postgresql-service

   # Check startup order
   docker compose ps -a
   ```

3. **Verify configuration:**
   ```bash
   docker compose convert | grep <service-name> -A 20
   ```

4. **Check resources:**
   ```bash
   docker stats
   free -h
   df -h
   ```

See [Troubleshooting - Container Health Checks](./troubleshooting.md#container-health-checks-failing).

### Cannot Access Web UI

**Symptoms:**
- Browser shows "connection refused"
- 404 errors
- Blank pages

**Debug steps:**

1. **Verify nginx is running:**
   ```bash
   docker compose ps nginx-ui-gateway
   docker container logs adempiere-ui-gateway.nginx-ui-gateway
   ```

2. **Test nginx configuration:**
   ```bash
   docker exec adempiere-ui-gateway.nginx-ui-gateway nginx -t
   ```

3. **Check backend service:**
   ```bash
   # For ZK UI
   docker compose ps adempiere-zk
   docker container logs adempiere-ui-gateway.zk

   # For Vue UI
   docker compose ps vue-ui
   docker container logs adempiere-ui-gateway.vue-ui
   ```

4. **Test from inside nginx:**
   ```bash
   docker exec adempiere-ui-gateway.nginx-ui-gateway curl http://adempiere-zk:8080
   ```

See [Troubleshooting - Network Issues](./troubleshooting.md#network-and-access-issues).

### Database Connection Errors

**Symptoms:**
- Services log "could not connect to server"
- "connection refused" errors
- "database does not exist"

**Debug steps:**

1. **Verify PostgreSQL is healthy:**
   ```bash
   docker compose ps postgresql-service
   docker exec adempiere-ui-gateway.postgresql pg_isready -U postgres
   ```

2. **Check database exists:**
   ```bash
   docker exec adempiere-ui-gateway.postgresql psql -U postgres -l
   ```

3. **Test connection:**
   ```bash
   docker exec -it adempiere-ui-gateway.postgresql \
     psql -U adempiere -d adempiere -c "SELECT version();"
   ```

4. **Check logs:**
   ```bash
   docker container logs adempiere-ui-gateway.postgresql | tail -50
   ```

See [Troubleshooting - Database Issues](./troubleshooting.md#database-issues).

### Envoy Crashes: "Could Not Find Service in Proto Descriptor"

**Symptoms:**
- `adempiere-ui-gateway.envoy-grpc-proxy` fails to start (exit code 1)
- Log shows: `transcoding_filter: Could not find 'form.some_service.SomeService' in the proto descriptor`
- Dependent services (nginx) also fail to start

**Cause:** When adding new gRPC services, three things must be updated — and the docker-compose volume mount is the easiest to forget.

**Three-step checklist — all three are required:**

1. **Proto descriptor file** (`.dsc`) — regenerate from source `.proto` files using `protoc`; must include ALL services (old + new)
   - Location: `docker-compose/envoy/definitions/adempiere-grpc-server.dsc`

2. **`envoy.yaml`** — add new services to the transcoding services list; update `proto_descriptor` path if filename changed
   - Location: `docker-compose/envoy/envoy.yaml`

3. **Volume mounts in `docker-compose.yml`** ← **easy to forget!** — mount the descriptor file into the container's `/data/` directory

**Example volume mount:**
```yaml
volumes:
  - ./envoy/envoy.yaml:/etc/envoy/envoy.yaml:ro
  - ./envoy/definitions/adempiere-grpc-server.dsc:/data/adempiere-grpc-server.dsc:ro
```

**Verification:**
```bash
# Check descriptor contains the service:
grep -a "SomeService" docker-compose/envoy/definitions/adempiere-grpc-server.dsc

# Verify volume mount is present in docker-compose.yml:
grep "adempiere-grpc-server.dsc" docker-compose/docker-compose.yml

# Check envoy startup log:
docker container logs adempiere-ui-gateway.envoy-grpc-proxy
```

---

### Slow Performance

**Symptoms:**
- Slow page loads
- High CPU usage
- Out of memory errors

**Debug steps:**

1. **Monitor resources:**
   ```bash
   docker stats
   ```

2. **Check disk space:**
   ```bash
   df -h
   docker system df
   ```

3. **Review system requirements:**
   See [System Requirements](./system-requirements.md)

4. **Check PostgreSQL performance:**
   ```bash
   docker exec adempiere-ui-gateway.postgresql \
     psql -U adempiere -d adempiere \
     -c "SELECT pid, query, state FROM pg_stat_activity WHERE state != 'idle';"
   ```

See [Troubleshooting - Performance Issues](./troubleshooting.md#performance-issues).

---

## Additional Resources

- **[Troubleshooting Guide](./troubleshooting.md)** - Common problems and solutions
- **[Architecture Documentation](./architecture.md)** - Health checks, dependencies, startup order
- **[Services Documentation](./services.md)** - Complete service reference
- **[Backup and Restore Guide](./backup-restore.md)** - Database operations
- **[System Requirements](./system-requirements.md)** - Resource planning
- **[Kafka Debugging Guide](./debugging-kafka.md)** - Kafka CLI testing (topics, produce, consume, consumer groups)
- **[Scripts README](./scripts/README.md)** - Diagnostic script documentation

---

[Back to README](../README.md) | [Previous: Backup and Restore](./backup-restore.md) | [Next: Debugging Vue Frontend](./debugging-vue-frontend.md)

