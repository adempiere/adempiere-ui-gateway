# Backup and Restore Guide

This guide provides comprehensive procedures for backing up and restoring your ADempiere UI Gateway stack, with a focus on the PostgreSQL database which contains all your critical business data.

## Index

| Section | Description |
|---------|-------------|
| [Why Backups Are Critical](#why-backups-are-critical) | What you lose without backups |
| [What to Back Up](#what-to-back-up) | Critical, important, and optional data |
| [Database Backup Procedures](#database-backup-procedures) | Quick, compressed, and custom format backups |
| [Automated Backup Script](#automated-backup-script) | Using the backup script with cron |
| [Database Restore Procedures](#database-restore-procedures) | Automatic, manual, interactive, compressed, and alternative restores |
| [Monitoring Restore Progress](#monitoring-restore-progress) | Table count, real-time progress, verification |
| [Post-Restore Tasks](#post-restore-tasks) | SQL scripts to run after restore |
| [Backup Verification](#backup-verification) | Quick and full verification procedures |
| [Backup Strategy Recommendations](#backup-strategy-recommendations) | Dev/testing, production, 3-2-1 rule |
| [Offsite Backup Storage](#offsite-backup-storage) | SCP and cloud storage |
| [Backup Other Components](#backup-other-components) | Environment config and Docker volumes |
| [Disaster Recovery Procedures](#disaster-recovery-procedures) | Complete system failure recovery |
| [Troubleshooting Backup/Restore Issues](#troubleshooting-backuprestore-issues) | Permission errors, disk space, corruption, and more |
| [Best Practices Summary](#best-practices-summary) | Key recommendations at a glance |
| [Backup Checklist](#backup-checklist) | Pre-backup and verification checklist |
| [See Also](#see-also) | Links to related documentation |

---

## Why Backups Are Critical

**Without regular backups, you risk:**
- ❌ Total data loss from hardware failure
- ❌ Data corruption from software bugs
- ❌ Accidental deletion of critical data
- ❌ Inability to recover from security incidents
- ❌ No way to migrate to new hardware

**With proper backups, you can:**
- ✅ Recover from any disaster
- ✅ Migrate to new servers confidently
- ✅ Test upgrades safely
- ✅ Restore specific points in time
- ✅ Meet compliance requirements

---

## What to Back Up

### Critical (Must Back Up)

1. **PostgreSQL Database** - Contains all business data
   - Location: `docker-compose/postgresql/postgres_database/`
   - Backup format: SQL dump files
   - **This is your most critical asset**

2. **Environment Configuration**
   - File: `docker-compose/env_template.env`
   - Contains all your customizations and settings

3. **Custom nginx Configuration** (if modified)
   - Location: `docker-compose/nginx/`
   - Any custom routing or SSL configurations

### Important (Should Back Up)

4. **Persistent Files (ZK container)**
   - Location: `docker-compose/postgresql/persistent_files/`
   - Shared files between host and ZK container

5. **Custom Docker Compose Modifications**
   - File: `docker-compose/docker-compose.yml` (if customized)
   - Any service-specific customizations

6. **S3 Storage Data** (if using MinIO)
   - Docker volume: `volume_s3`
   - Reports, attachments, uploaded files

### Optional (Nice to Have)

7. **DKron Scheduler Data**
   - Docker volume: `volume_dkron`
   - Scheduled job definitions

8. **OpenSearch Indexes**
   - Docker volume: `volume_opensearch`
   - Dictionary cache (can be rebuilt)

---

## Database Backup Procedures

### Quick Backup (Recommended for Regular Use)

The simplest and most common backup method - creates a SQL dump file:

```bash
# Navigate to backups directory
cd docker-compose/postgresql/postgres_backups/

# Create timestamped backup
docker exec -i adempiere-ui-gateway.postgresql pg_dump \
  --no-owner \
  -h localhost \
  -U postgres \
  adempiere > adempiere-$(date '+%Y-%m-%d-%H%M%S').backup

# Verify backup was created
ls -lh adempiere-*.backup
```

**What this does:**
- Creates a plain-text SQL dump
- Includes all tables, data, sequences
- Excludes ownership information (portable across systems)
- Names file with timestamp for easy identification

**Expected output:**
```
-rw-rw-r-- 1 user user 245M Feb 13 10:30 adempiere-2026-02-13-103045.backup
```

### Compressed Backup (Save Disk Space)

For large databases, compress the backup to save space:

```bash
cd docker-compose/postgresql/postgres_backups/

# Create compressed backup
docker exec -i adempiere-ui-gateway.postgresql pg_dump \
  --no-owner \
  -h localhost \
  -U postgres \
  adempiere | gzip > adempiere-$(date '+%Y-%m-%d-%H%M%S').backup.gz

# Verify compression ratio
ls -lh adempiere-*.backup*
```

**Typical compression:** 245 MB → 45 MB (80% reduction)

### Custom Format Backup (Advanced)

PostgreSQL's custom format allows parallel restore and selective table restoration:

```bash
cd docker-compose/postgresql/postgres_backups/

# Create custom format backup
docker exec -i adempiere-ui-gateway.postgresql pg_dump \
  --format=custom \
  --no-owner \
  -h localhost \
  -U postgres \
  adempiere > adempiere-$(date '+%Y-%m-%d-%H%M%S').custom

# List backup contents
pg_restore --list adempiere-2026-02-13-103045.custom | less
```

**Advantages:**
- Can restore specific tables
- Supports parallel restore (faster)
- Built-in compression
- More robust than plain SQL

**Disadvantages:**
- Not human-readable
- Requires pg_restore (not psql)

---

## Automated Backup Script

We provide a ready-to-use backup script: **[04-backup-database.sh](./scripts/04-backup-database.sh)**

**Features:**
- ✅ Creates timestamped backup files
- ✅ Compresses backups with gzip (~80% size reduction)
- ✅ Implements 30-day retention policy
- ✅ Verifies container and database existence
- ✅ Provides detailed progress output
- ✅ Calculates compression ratios
- ✅ Shows disk usage statistics

**Location:** `docs/scripts/04-backup-database.sh`

### Using the Backup Script

**Manual backup:**

```bash
# Navigate to scripts directory
cd docs/scripts/

# Run the script
./04-backup-database.sh

# Or specify custom backup directory
./04-backup-database.sh /path/to/custom/backup/directory
```

**Example output:**
```
==========================================
ADempiere Database Backup
==========================================
Date: Thu Feb 13 11:30:45 CST 2026
Database: adempiere
Container: adempiere-ui-gateway.postgresql
Backup directory: ../../docker-compose/postgresql/postgres_backups

Creating backup...
✅ Backup created successfully: adempiere-2026-02-13-113045.backup
   Size: 245M

Compressing backup...
✅ Backup compressed: adempiere-2026-02-13-113045.backup.gz
   Compressed size: 45M
   Compression ratio: ~82%

Cleaning old backups (keeping last 30 days)...
🗑️  Deleted 3 old backup(s)
📦 Backups remaining: 28

Backup directory disk usage:
1.2G    ../../docker-compose/postgresql/postgres_backups

==========================================
✅ Backup completed successfully!
==========================================

Backup file: adempiere-2026-02-13-113045.backup.gz

To restore this backup, see:
  docs/backup-restore.md#database-restore-procedures
```

### Automated Daily Backups

**Schedule with cron:**

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /path/to/adempiere-ui-gateway/docs/scripts && ./04-backup-database.sh >> /var/log/adempiere-backup.log 2>&1
```

**Schedule with systemd timer:**

Create service file `/etc/systemd/system/adempiere-backup.service`:
```ini
[Unit]
Description=ADempiere Database Backup

[Service]
Type=oneshot
User=your-user
WorkingDirectory=/path/to/adempiere-ui-gateway/docs/scripts
ExecStart=/path/to/adempiere-ui-gateway/docs/scripts/04-backup-database.sh
```

Create timer file `/etc/systemd/system/adempiere-backup.timer`:
```ini
[Unit]
Description=ADempiere Database Backup Timer

[Timer]
OnCalendar=daily
OnCalendar=02:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start:
```bash
sudo systemctl enable adempiere-backup.timer
sudo systemctl start adempiere-backup.timer

# Check status
sudo systemctl status adempiere-backup.timer
```

---

## Database Restore Procedures

### Automatic Restore (On First Startup)

The stack automatically restores from a seed file on first startup:

**Conditions for automatic restore:**
1. Database directory is empty: `postgresql/postgres_database/` has no contents
2. Seed file exists: `postgresql/postgres_backups/seed.backup`
3. Stack is starting for the first time

**How it works:**
- The `initdb.sh` script runs when PostgreSQL container starts
- Checks if database "adempiere" exists
- If not, looks for `seed.backup` file
- Restores database from seed file
- If no seed file found, downloads latest from GitHub

**To trigger automatic restore:**

```bash
# 1. Stop all containers
cd docker-compose/
./stop-all.sh

# 2. Delete database directory
sudo rm -rf postgresql/postgres_database/*

# 3. Copy your backup as seed file
cp postgresql/postgres_backups/adempiere-2026-02-13-103045.backup postgresql/postgres_backups/seed.backup

# 4. Start stack - restore happens automatically
./start-all.sh

# 5. Monitor restore progress
docker compose logs -f postgresql-service
```

### Manual Restore (Existing Database)

To restore without deleting the database directory:

```bash
# 1. Stop all services EXCEPT PostgreSQL
docker compose stop adempiere-zk vue-ui adempiere-grpc-server grpc-proxy ui-gateway

# 2. Drop existing database (CAUTION!)
# Using WITH (FORCE) to disconnect any active sessions
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -c "DROP DATABASE adempiere WITH (FORCE);"

# 3. Create fresh database with proper owner and search path
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -c "CREATE DATABASE adempiere WITH OWNER=adempiere;"
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -c "ALTER DATABASE adempiere SET search_path = adempiere, public;"

# 4. Restore from backup
docker exec -i adempiere-ui-gateway.postgresql psql -U adempiere -d adempiere < postgresql/postgres_backups/<your-backup-file>.backup

# 5. Verify restore
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -d adempiere -c "SELECT COUNT(*) FROM ad_table;"
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -d adempiere -c "SELECT name FROM ad_client;"

# 6. Restart all services
docker compose start
```

**Important notes:**
- `DROP DATABASE WITH (FORCE)` disconnects active sessions before dropping
- `ALTER DATABASE SET search_path` ensures ADempiere finds its tables correctly
- Use `-U adempiere` for restore (not postgres) to maintain proper ownership

### Interactive Restore (From Inside Container)

This method is useful when you want to work interactively inside the PostgreSQL container:

```bash
# 1. Copy backup to the backups directory (if not already there)
cp /path/to/backup.backup postgresql/postgres_backups/

# 2. Enter the PostgreSQL container
docker exec -it adempiere-ui-gateway.postgresql bash

# 3. Navigate to backups directory
cd /home/adempiere/postgres_backups

# 4. Connect to PostgreSQL
psql -U postgres -d postgres

# 5. Check existing database (optional)
\l
\c adempiere
SELECT name FROM ad_client;
\c postgres

# 6. Drop existing database (if exists)
DROP DATABASE adempiere WITH (FORCE);

# 7. Create fresh database
CREATE DATABASE adempiere WITH OWNER=adempiere;
ALTER DATABASE adempiere SET search_path = adempiere, public;

# 8. Exit psql
\q

# 9. Restore from backup file
psql -U adempiere -d adempiere < /home/adempiere/postgres_backups/seed.backup

# 10. Verify restore
psql -U postgres -d adempiere
SELECT COUNT(*) FROM ad_table;
SELECT name FROM ad_client;
\q

# 11. Exit container
exit
```

**Useful psql commands:**
- `\l` - List all databases
- `\c database_name` - Connect to a database
- `\dt` - List all tables in current database
- `\d table_name` - Describe table structure
- `\q` - Quit psql

### Restore from Compressed Backup

If your backup is compressed (`.gz` file):

**Method 1: Decompress and restore in one command (from host)**
```bash
gunzip -c postgresql/postgres_backups/<your-backup-file>.backup.gz | \
  docker exec -i adempiere-ui-gateway.postgresql psql -U adempiere -d adempiere
```

**Method 2: Decompress first, then restore (from inside container)**
```bash
# Enter container
docker exec -it adempiere-ui-gateway.postgresql bash
cd /home/adempiere/postgres_backups

# Decompress
gzip -dckv <your-backup-file>.backup.gz > <your-backup-file>.backup

# Restore
psql -U adempiere -d adempiere < <your-backup-file>.backup

# Clean up decompressed file (optional)
rm <your-backup-file>.backup
exit
```

**gzip options explained:**
- `-d` = decompress
- `-c` = write to stdout
- `-k` = keep original file
- `-v` = verbose output

### Restore from Custom Format Backup

If you used custom format (pg_dump --format=custom):

```bash
# Restore entire database
docker exec -i adempiere-ui-gateway.postgresql pg_restore \
  --no-owner \
  -h localhost \
  -U postgres \
  -d adempiere \
  /home/adempiere/postgres_backups/<your-backup-file>.custom

# Or restore specific tables only
docker exec -i adempiere-ui-gateway.postgresql pg_restore \
  --no-owner \
  -h localhost \
  -U postgres \
  -d adempiere \
  --table=ad_user \
  --table=c_order \
  /home/adempiere/postgres_backups/<your-backup-file>.custom
```

### Alternative Restore Method (pg_restore)

If `psql` restore fails, try `pg_restore` as an alternative:

```bash
# Enter container
docker exec -it adempiere-ui-gateway.postgresql bash

# Switch to postgres user
su postgres

# Restore using pg_restore
pg_restore -d adempiere -v /home/adempiere/postgres_backups/<your-backup-file>.backup

# Exit
exit
exit
```

**When to use pg_restore instead of psql:**
- When dealing with binary backup formats
- When you need verbose output (`-v` flag)
- When psql fails with format-related errors

---

## Monitoring Restore Progress

For large databases, restores can take significant time. Use these commands to monitor progress:

### Check Table Count

Monitor how many tables have been restored:

```bash
# Check total tables restored
docker exec adempiere-ui-gateway.postgresql \
  psql -U adempiere -d adempiere -t \
  -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'adempiere'"

# Expected: ~760 tables for complete ADempiere database
```

### Monitor Restore Progress in Real-Time

Open a second terminal and run this command repeatedly:

```bash
# Check table count every 5 seconds
watch -n 5 "docker exec adempiere-ui-gateway.postgresql \
  psql -U adempiere -d adempiere -t \
  -c \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'adempiere'\""

# Press Ctrl+C to stop monitoring when complete
```

### Verify Restore Completion

After restore finishes, verify critical database elements:

```bash
# 1. Check if ACLs (Access Control Lists) are set
docker exec adempiere-ui-gateway.postgresql \
  psql -U adempiere -d adempiere -t \
  -c "SELECT EXISTS (SELECT 1 FROM information_schema.column_privileges
      WHERE table_schema = 'adempiere' AND table_name = 'rv_inout_createfrom'
      AND column_name = 'name')"
# Expected: t (true)

# 2. Check if foreign key constraints exist
docker exec adempiere-ui-gateway.postgresql \
  psql -U adempiere -d adempiere -t \
  -c "SELECT COUNT(*) FROM information_schema.table_constraints
      WHERE constraint_schema = 'adempiere' AND constraint_type = 'FOREIGN KEY'"
# Expected: Several hundred constraints

# 3. Verify specific tables exist
docker exec adempiere-ui-gateway.postgresql \
  psql -U adempiere -d adempiere -t \
  -c "SELECT EXISTS (SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'adempiere' AND table_name = 'ad_client')"
# Expected: t (true)
```

### Health Check for Restored Database

Run the same health check used by Docker Compose:

```bash
# Manual health check
docker exec adempiere-ui-gateway.postgresql bash -c \
  "pg_isready -U postgres && \
   psql -U adempiere -d adempiere -t -c \
   'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '\''adempiere'\''' | grep -q '760'"

# If exit code is 0, database is healthy
echo $?
```

---

## Post-Restore Tasks

### Execute SQL Scripts

After restore, you may need to run additional SQL scripts (migrations, fixes, customizations):

**Method 1: From host machine**
```bash
docker exec -i adempiere-ui-gateway.postgresql \
  psql -h localhost -U postgres -d adempiere -a \
  -f /home/adempiere/postgres_backups/<your-script>.sql
```

**Method 2: From inside container**
```bash
# Enter container
docker exec -it adempiere-ui-gateway.postgresql bash

# Execute SQL file
psql -h localhost -U postgres -d adempiere -a -f /home/adempiere/postgres_backups/<your-script>.sql

# Or interactively in psql
psql -U postgres -d adempiere
\i /home/adempiere/postgres_backups/<your-script>.sql
\q

exit
```

**Options explained:**
- `-a` = echo all input from the file
- `-f` = execute commands from file
- `\i` = psql internal command to execute file

---

## Backup Verification

**Always verify your backups!** An untested backup is not a backup.

### Quick Verification

Check backup file integrity:

```bash
# 1. Check file exists and has reasonable size
ls -lh postgresql/postgres_backups/<your-backup-file>.backup
# Should be > 50 MB for typical database

# 2. Check if file is valid SQL (plain format)
head -n 20 postgresql/postgres_backups/<your-backup-file>.backup
# Should show SQL commands

# 3. Count SQL statements (rough check)
grep -c "^INSERT INTO" postgresql/postgres_backups/<your-backup-file>.backup
# Should show thousands of INSERT statements
```

### Full Verification (Test Restore)

The only way to truly verify a backup is to test restore it:

```bash
# 1. Create test database
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -c "CREATE DATABASE adempiere_test;"

# 2. Restore backup to test database
docker exec -i adempiere-ui-gateway.postgresql psql -U postgres -d adempiere_test < postgresql/postgres_backups/<your-backup-file>.backup

# 3. Verify data
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -d adempiere_test -c "
  SELECT
    (SELECT COUNT(*) FROM ad_table) as tables,
    (SELECT COUNT(*) FROM ad_user) as users,
    (SELECT COUNT(*) FROM c_order) as orders;
"

# 4. Clean up test database
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -c "DROP DATABASE adempiere_test;"
```

**Schedule regular test restores** (monthly recommended) to ensure backups are recoverable.

---

## Backup Strategy Recommendations

### For Development/Testing

- **Frequency:** Daily or before major changes
- **Retention:** 7 days
- **Method:** Quick backup (plain SQL)
- **Storage:** Local disk only

### For Production (Small)

- **Frequency:** Daily (automated at 2 AM)
- **Retention:** 30 days
- **Method:** Compressed backup
- **Storage:** Local + offsite (cloud/remote server)
- **Test restore:** Monthly

### For Production (Medium/Large)

- **Frequency:**
  - Full backup: Daily at 2 AM
  - Incremental: Every 6 hours
- **Retention:**
  - Daily: 30 days
  - Weekly: 12 weeks
  - Monthly: 12 months
- **Method:** Custom format (parallel restore capability)
- **Storage:** Local + offsite + archive
- **Test restore:** Weekly

### 3-2-1 Backup Rule

Follow the industry-standard 3-2-1 rule:

- **3** copies of data (original + 2 backups)
- **2** different media types (local disk + cloud)
- **1** copy offsite (cloud storage, remote server)

---

## Offsite Backup Storage

### Copy to Remote Server (SCP)

```bash
# Copy backup to remote server
scp postgresql/postgres_backups/<your-backup-file>.backup.gz \
  user@remote-server:/backups/adempiere/

# Or use rsync for incremental transfers (copies entire directory)
rsync -avz --progress \
  postgresql/postgres_backups/ \
  user@remote-server:/backups/adempiere/
```

### Upload to Cloud Storage

**AWS S3:**
```bash
# Install AWS CLI
apt install awscli

# Configure credentials
aws configure

# Upload backup
aws s3 cp postgresql/postgres_backups/<your-backup-file>.backup.gz \
  s3://my-bucket/adempiere-backups/
```

**Google Cloud Storage:**
```bash
# Install gsutil
curl https://sdk.cloud.google.com | bash

# Upload backup
gsutil cp postgresql/postgres_backups/<your-backup-file>.backup.gz \
  gs://my-bucket/adempiere-backups/
```

---

## Backup Other Components

### Environment Configuration

```bash
# Backup env file
cp docker-compose/env_template.env backups/env_template.env-$(date '+%Y-%m-%d')

# Or backup entire docker-compose directory (excluding data)
tar -czf adempiere-config-$(date '+%Y-%m-%d').tar.gz \
  --exclude='postgres_database' \
  --exclude='postgres_backups' \
  docker-compose/
```

### Docker Volumes (S3, DKron, OpenSearch)

```bash
# Backup a Docker volume
docker run --rm \
  -v adempiere-ui-gateway.volume_s3:/data \
  -v $(pwd)/backups:/backup \
  alpine \
  tar -czf /backup/s3-volume-$(date '+%Y-%m-%d').tar.gz -C /data .

# Restore a Docker volume
docker run --rm \
  -v adempiere-ui-gateway.volume_s3:/data \
  -v $(pwd)/backups:/backup \
  alpine \
  tar -xzf /backup/<your-volume-backup>.tar.gz -C /data
```

---

## Disaster Recovery Procedures

### Complete System Failure

If your server crashes or becomes unrecoverable:

1. **Install fresh server** with same OS
2. **Install Docker and Docker Compose**
3. **Clone repository:**
   ```bash
   git clone https://github.com/adempiere/adempiere-ui-gateway.git
   cd adempiere-ui-gateway/docker-compose
   ```
4. **Restore configuration:**
   ```bash
   cp /path/to/backup/env_template.env ./env_template.env
   ```
5. **Place database backup:**
   ```bash
   mkdir -p postgresql/postgres_backups
   cp /path/to/backup/adempiere-latest.backup postgresql/postgres_backups/seed.backup
   ```
6. **Start stack** (automatic restore will occur):
   ```bash
   ./start-all.sh
   ```
7. **Verify services:**
   ```bash
   docker compose ps
   curl http://localhost/webui
   ```

**Expected time:** 15-30 minutes for complete recovery

---

## Troubleshooting Backup/Restore Issues

### Backup Fails: "Permission Denied"

**Problem:** Can't write to backup directory

**Solution:**
```bash
# Check directory permissions
ls -la postgresql/postgres_backups/

# Fix permissions
sudo chown -R $USER:$USER postgresql/postgres_backups/
chmod 755 postgresql/postgres_backups/
```

### Restore Fails: "Database Already Exists"

**Problem:** Automatic restore skipped because database exists

**Solution:**
```bash
# Option 1: Delete database directory
sudo rm -rf postgresql/postgres_database/*

# Option 2: Drop database manually (see Manual Restore section above)
```

### Restore Fails: "Database is Being Accessed by Other Users"

**Problem:** Cannot drop database because other sessions are connected

**Error message:**
```
ERROR:  database "adempiere" is being accessed by other users
DETAIL:  There is 1 other session using the database.
```

**Solution:** Use `WITH (FORCE)` to disconnect active sessions:
```bash
# Force disconnect all sessions and drop database
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -c "DROP DATABASE adempiere WITH (FORCE);"
```

**Alternative:** Manually terminate connections first:
```bash
# Terminate all connections to the database
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -c "
  SELECT pg_terminate_backend(pg_stat_activity.pid)
  FROM pg_stat_activity
  WHERE pg_stat_activity.datname = 'adempiere'
    AND pid <> pg_backend_pid();
"

# Then drop database
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -c "DROP DATABASE adempiere;"
```

### Restore Fails: "Role Does Not Exist"

**Problem:** Backup includes ownership information

**Solution:** Always use `--no-owner` flag when creating backups:
```bash
docker exec -i adempiere-ui-gateway.postgresql pg_dump --no-owner ...
```

### After Restore: "Relation Does Not Exist" Errors

**Problem:** ADempiere cannot find its tables after restore

**Cause:** Missing or incorrect `search_path` configuration

**Error examples:**
```
ERROR: relation "ad_table" does not exist
ERROR: schema "adempiere" does not exist
```

**Solution:** Set the search path for the database:
```bash
# Set search path
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -c "ALTER DATABASE adempiere SET search_path = adempiere, public;"

# Verify search path is set
docker exec -it adempiere-ui-gateway.postgresql psql -U postgres -d adempiere -c "SHOW search_path;"
# Should show: adempiere, public

# Reconnect services for changes to take effect
docker compose restart adempiere-zk vue-ui adempiere-grpc-server
```

**Why this matters:**
- ADempiere uses a schema named "adempiere" for its tables
- PostgreSQL needs to know where to look for tables
- The search_path tells PostgreSQL which schemas to search
- Without correct search_path, PostgreSQL looks only in "public" schema

### Backup File Corrupted

**Problem:** Backup file is corrupted or incomplete

**Solution:**
```bash
# Check if file is valid SQL
head -n 100 backup-file.backup

# Check for errors in backup
grep -i error backup-file.backup

# If corrupted, restore from previous backup
```

### Out of Disk Space During Backup

**Problem:** Not enough space for backup

**Solution:**
```bash
# Check available space
df -h

# Clean old backups
rm postgresql/postgres_backups/adempiere-old-*.backup

# Use compressed backup
docker exec -i adempiere-ui-gateway.postgresql pg_dump ... | gzip > backup.gz
```

---

## Best Practices Summary

✅ **DO:**
- Back up daily (minimum)
- Test restores regularly (monthly)
- Store backups offsite (cloud/remote)
- Use compressed backups for large databases
- Automate backups with cron/scheduler
- Document restore procedures
- Monitor backup success/failure
- Keep multiple backup generations

❌ **DON'T:**
- Rely on only one backup
- Store backups only on same server as database
- Assume backups work without testing
- Delete old backups without retention policy
- Skip backing up configuration files
- Use production database for testing
- Ignore backup failure alerts

---

## Backup Checklist

Use this checklist for your backup strategy:

- [ ] Daily automated backups configured
- [ ] Backup script tested and working
- [ ] Retention policy defined and implemented
- [ ] Offsite backup location configured
- [ ] Backup monitoring/alerting in place
- [ ] Restore procedure documented
- [ ] Test restore performed and verified
- [ ] Configuration files backed up
- [ ] Team trained on restore procedures
- [ ] Disaster recovery plan documented

---

## See Also

- [System Requirements](./system-requirements.md) - Disk space planning for backups
- [Troubleshooting Guide](./troubleshooting.md) - Database restore issues
- [Installation Guide](./installation.md) - Initial database setup

---

[Back to README](../README.md) | [Previous: Security](./security.md) | [Next: Debugging](./debugging.md)

