# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the ADempiere UI Gateway stack.

## Quick Diagnostic Commands

Before diving into specific issues, these commands help identify problems:

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

**Solution:** Wait 2-3 minutes after running `docker compose up`, then check status again.

```bash
# Wait 2 minutes, then check
sleep 120
docker compose ps
```

If containers are still "starting" after 5 minutes, then investigate further.

#### 2. Insufficient Memory

**Symptoms:**
- Containers repeatedly restarting
- "OOMKilled" in container status
- Java heap space errors in logs

**Check:**
```bash
# Check if containers were killed due to memory
docker compose ps -a | grep -i "oom"

# Check container logs for memory errors
docker compose logs opensearch-node | grep -i "memory\|heap"
```

**Solution:**
- Increase host RAM (minimum 8 GB, recommended 16 GB)
- Reduce services using specific profiles instead of `all`
- Configure memory limits in docker-compose.yml

#### 3. Port Conflicts

**Symptoms:**
- Container fails to start
- Error: "port is already allocated"

**Check:**
```bash
# Check what's using port 80 (nginx)
sudo lsof -i :80

# Check PostgreSQL port
sudo lsof -i :55432
```

**Solution:**
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

**Symptoms:**
- PostgreSQL unhealthy
- Other services waiting for database
- "database does not exist" errors

**Check:**
```bash
docker compose logs postgresql-service | grep -i "error\|failed"
```

**Solution:** See [Database Issues](#database-issues) section below.

---

## Database Issues

### Database Won't Restore

**Symptoms:**
- PostgreSQL starts but database is empty
- No ADempiere data
- Login fails

**Common Causes:**

#### 1. Database Directory Already Exists

The restore only happens if `postgresql/postgres_database/` is empty.

**Check:**
```bash
ls -la postgresql/postgres_database/
```

**Solution:** Delete the database directory and restart:

```bash
# Stop containers
./stop-all.sh

# Delete database (CAUTION: This deletes all data!)
sudo rm -rf postgresql/postgres_database/*

# Restart - restore will happen automatically
./start-all.sh
```

#### 2. Seed File Not Found

**Check:**
```bash
ls -la postgresql/postgres_backups/seed.backup
```

**Solution:** Place a valid backup file:

```bash
# Copy your backup file
cp /path/to/your/backup.backup postgresql/postgres_backups/seed.backup

# Or download from GitHub (latest ADempiere seed)
# The script will do this automatically if no seed.backup exists
```

#### 3. Restore File Corrupted

**Check logs:**
```bash
docker compose logs postgresql-service | grep -i "restore\|pg_restore"
```

**Solution:** Get a fresh backup file and try again.

### Database Connection Refused

**Symptoms:**
- Services can't connect to database
- Error: "connection refused" or "could not connect to server"

**Check:**
```bash
# Check if PostgreSQL is running
docker compose ps postgresql-service

# Check PostgreSQL logs
docker compose logs postgresql-service

# Try connecting from host
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -d adempiere -c "SELECT version();"
```

**Solution:**
- Wait for PostgreSQL to fully start (30 seconds)
- Check health status: `docker compose ps`
- Verify credentials in `env_template.env`

### Database Already Exists (No Restore Happening)

**Symptom:**
You want a fresh restore, but the database already exists and restore is skipped.

**Solution:**

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

**See also:** [Diagnostic Scripts README](./scripts/README.md) for detailed usage information.

**Expected output:**
- All containers should show `Time diff: 0s (OK)`
- All containers should have `TZ env var` set to same timezone (e.g., `Europe/Berlin`, `America/New_York`, etc.)

### Common Issues

#### 1. TZ Environment Variable Not Set

**Symptom:**
```
Container: adempiere-ui-gateway.site
  TZ env var: not set
  Date: Fri Feb 13 14:55:24 UTC 2026
```

**Solution:** Add TZ to the service in `docker-compose.yml`:

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

**Symptom:**
```
Container: adempiere-ui-gateway.s3-storage
  Date: Fri Feb 13 14:41:53 UTC 2026  (displays UTC despite TZ setting)
  TZ env var: Europe/Berlin
```

**Cause:** Some containers' `date` command doesn't properly respect the TZ environment variable.

**Check:**
```bash
# Check if container has timezone data (example: Europe)
docker exec adempiere-ui-gateway.s3-storage ls -la /usr/share/zoneinfo/Europe/

# Check /etc/localtime
docker exec adempiere-ui-gateway.s3-storage ls -la /etc/localtime
```

**Solution:** Container may need timezone data mounted or installed. This is usually cosmetic (timestamps are still correct, just displayed in UTC).

#### 3. Containers Created Before TZ Configuration

**Symptom:** Old containers don't have TZ set, new ones do.

**Solution:** Recreate all containers:

```bash
cd docker-compose/
./stop-all.sh
./start-all.sh
```

### Understanding Timezone Configuration

The TZ environment variable **overrides** file-based timezone settings:

**Priority (highest to lowest):**
1. `TZ` environment variable (preferred method)
2. `/etc/localtime` symlink
3. `/etc/timezone` file

**Why times show as synchronized even with different timezones:**
- Unix timestamps are always UTC internally
- Display timezone (TZ variable) only affects how time is formatted
- Time difference = 0s means clocks are synchronized (correct)
- Different display formats are cosmetic

---

## Container Start/Stop Issues

### Containers Won't Start

#### 1. Dependency Issues

**Symptom:**
```
adempiere-ui-gateway.vue-ui        Exited (1)
Depends on: adempiere-grpc-server (not healthy yet)
```

**Solution:** Dependencies require health checks to pass. Wait for dependent services:

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

**Symptom:**
```
Error: Conflict. The container name "/adempiere-ui-gateway.zk" is already in use
```

**Solution:**

```bash
# Remove old containers
docker compose down

# Or force remove specific container
docker rm -f adempiere-ui-gateway.zk

# Recreate
docker compose up -d
```

#### 3. Image Pull Failed

**Symptom:**
```
Error: pull access denied for openls/dictionary-rs, repository does not exist
```

**Solution:**
- Check internet connection
- Verify image name in `env_template.env`
- Check if image exists on Docker Hub
- Try manual pull: `docker pull <image-name>:<tag>`

### Containers Keep Restarting

**Check restart count:**
```bash
docker compose ps -a
```

**Check why it's failing:**
```bash
docker compose logs <service-name> --tail 100
```

**Common causes:**
- Missing environment variables
- Failed health checks (see above)
- Application crashes (check logs)
- Resource limits exceeded

---

## Network and Access Issues

### Can't Access Application (Port 80)

**Symptoms:**
- Browser shows "connection refused" or "site can't be reached"
- URL: `http://<HOST_IP>/` doesn't work

**Diagnosis:**

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

**Solutions:**

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

**Check:**
```bash
grep HOST_IP docker-compose/env_template.env
```

**Fix:**
```bash
nano docker-compose/env_template.env
# Set HOST_IP to your actual IP or domain
HOST_IP=192.168.1.100

# Restart
./stop-all.sh
./start-all.sh
```

### Can't Access ZK UI or Vue UI

**Test the paths:**
```bash
curl http://<HOST_IP>/webui
curl http://<HOST_IP>/vue
```

**Check nginx routing:**
```bash
docker exec adempiere-ui-gateway.nginx-ui-gateway cat /etc/nginx/conf.d/api_gateway.conf
```

**Check backend services are running:**
```bash
docker compose ps adempiere-zk
docker compose ps vue-ui
```

### Internal Container Communication Issues

**Symptom:** Services can't reach each other (e.g., Vue can't connect to gRPC backend)

**Check network:**
```bash
# List networks
docker network ls

# Inspect the adempiere network
docker network inspect adempiere-ui-gateway.network

# Check if containers are on same network
docker inspect adempiere-ui-gateway.vue-ui | grep NetworkMode
docker inspect adempiere-ui-gateway.adempiere-grpc-server | grep NetworkMode
```

**Test connectivity between containers:**
```bash
# From vue-ui to grpc-server
docker exec adempiere-ui-gateway.vue-ui ping adempiere-grpc-server

# From any container to postgres
docker exec adempiere-ui-gateway.vue-ui nc -zv postgresql-service 5432
```

---

## Performance Issues

### Slow Startup Times

**Normal startup times:**
- Total stack: 90-120 seconds
- OpenSearch: 60-120 seconds (Java initialization)
- Kafka: 60-90 seconds (Java initialization)

**If slower than 5 minutes:**

**Check:**
```bash
# Monitor container resource usage
docker stats

# Check host resources
htop  # or top
df -h  # disk space
```

**Solutions:**
1. **Use SSD instead of HDD** - 5-10x faster
2. **Increase RAM** - Less disk I/O
3. **Close other applications** - Free up resources
4. **Check disk I/O**: `iostat -x 1`

### Slow Application Response

**Diagnose:**

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

**Solutions:**

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

**Check which service is consuming resources:**

```bash
docker stats --no-stream | sort -k3 -h  # Sort by CPU
docker stats --no-stream | sort -k4 -h  # Sort by memory
```

**Common causes:**
- **OpenSearch** - Normal to use 2-4 GB
- **PostgreSQL** - Large queries or missing indexes
- **Java services** - Normal high startup CPU, should stabilize

**Solutions:**
- Add more RAM
- Optimize database queries
- Review application logs for errors causing retry loops

---

## Disk Space Issues

### Out of Disk Space

**Symptoms:**
- Container won't start
- Database restore fails
- Error: "no space left on device"

**Check:**
```bash
# Check overall disk space
df -h

# Check Docker-specific usage
docker system df

# Detailed breakdown
docker system df -v
```

**Solutions:**

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

**Full error:**
```
Error response from daemon: driver failed programming external connectivity
on endpoint adempiere-ui-gateway.nginx-ui-gateway:
Error starting userland proxy: listen tcp4 0.0.0.0:80: bind: address already in use
```

**Cause:** Port 80 already in use by another service.

**Solution:**
```bash
# Find what's using port 80
sudo lsof -i :80

# Stop that service (example: Apache)
sudo systemctl stop apache2

# Or change nginx port in env_template.env
```

### "connection refused" to PostgreSQL

**Error in logs:**
```
connection refused: could not connect to server: Connection refused
Is the server running on host "postgresql-service" and accepting TCP/IP connections on port 5432?
```

**Cause:** PostgreSQL not ready yet, or not running.

**Solution:**
```bash
# Check PostgreSQL status
docker compose ps postgresql-service

# Wait for it to be healthy
docker compose ps --format "table {{.Name}}\t{{.Health}}"

# Check logs
docker compose logs postgresql-service
```

### "unhealthy" Status Persists

**If container shows unhealthy for >5 minutes:**

```bash
# Check health check configuration
docker inspect adempiere-ui-gateway.opensearch | grep -A 10 Healthcheck

# Check what the health check is doing
docker exec adempiere-ui-gateway.opensearch <health-check-command>

# Example for OpenSearch:
docker exec adempiere-ui-gateway.opensearch bash -c 'printf "GET / HTTP/1.1\n\n" > /dev/tcp/127.0.0.1/9200; exit $?;'
```

### "no such file or directory" - seed.backup

**Error:**
```
pg_restore: error: could not open input file "/home/adempiere/postgres_backups/seed.backup": No such file or directory
```

**Solution:**
```bash
# Check if backup file exists
ls -la postgresql/postgres_backups/

# If missing, add a backup file
cp /path/to/backup.backup postgresql/postgres_backups/seed.backup

# Or let the script download from GitHub automatically
# (just ensure the file is named correctly)
```

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

3. **Check GitHub issues:** [ADempiere UI Gateway Issues](https://github.com/adempiere/adempiere-ui-gateway/issues)

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

[Back to README](../README.md) | [Previous: Debugging](./debugging.md)
