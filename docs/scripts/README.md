# Utility Scripts

This directory contains utility scripts for the ADempiere UI Gateway stack:
- **Diagnostic scripts** for troubleshooting
- **Backup scripts** for database management

## Timezone and Time Synchronization Scripts

These scripts help verify that all containers have synchronized time with the host and proper timezone configuration.

### 01-contaniner-times-mismatches.sh

**Purpose:** Quickly identify containers with time synchronization issues.

**Usage:**
```bash
./01-contaniner-times-mismatches.sh
```

**What it does:**
- Checks all running containers for time differences > 2 seconds from host
- Reports only containers with mismatches (silent if all synchronized)
- Exit code 0 = all synchronized, 1 = mismatches found

**When to use:**
- Quick health check for time synchronization
- Automated monitoring scripts
- Before/after timezone configuration changes

**Example output:**
```
==========================================
Container Time Synchronization Check
==========================================

Host Time: Fri Feb 13 08:41:50 CST 2026
Host Timestamp: 1770993710
Tolerance: ±2 seconds

Checking running containers...

✅ SUCCESS: All containers synchronized with host time
```

---

### 02-container-times-detailed.sh

**Purpose:** Comprehensive timezone configuration report for all containers.

**Usage:**
```bash
./02-container-times-detailed.sh
```

**What it does:**
- Shows detailed timezone configuration for each container
- Displays TZ environment variable, /etc/timezone, /etc/localtime
- Calculates time difference from host
- Lists all 20+ containers with full details

**When to use:**
- Diagnosing timezone configuration issues
- Understanding which containers have which timezone settings
- Documenting container timezone configuration

**Example output:**
```
==========================================
Container Time & Timezone Detailed Report
==========================================

HOST:
  Date:            Fri Feb 13 08:55:10 CST 2026
  Timestamp:       1770994510
  Timezone:        Europe/Berlin
  TZ variable:     Europe/Berlin

==========================================

[1] adempiere-ui-gateway.nginx-ui-gateway
  Date:            Fri Feb 13 08:55:10 CST 2026
  Timestamp:       1770994510
  Time diff:       0s (OK)
  TZ env var:      Europe/Berlin
  /etc/timezone:   not mounted or not readable
  /etc/localtime:  not mounted

[2] adempiere-ui-gateway.postgresql
  Date:            Fri 13 Feb 2026 08:55:11 AM CST
  Timestamp:       1770994511
  Time diff:       0s (OK)
  TZ env var:      Europe/Berlin
  /etc/timezone:   Etc/UTC
  /etc/localtime:  /usr/share/zoneinfo/Etc/UTC

...
```

---

### 03-all-container-times-simple.sh

**Purpose:** Simple tabular view of all container times for quick visual inspection.

**Usage:**
```bash
./03-all-container-times-simple.sh
```

**What it does:**
- Displays host time and all container times in a clean table
- Shows container name, current time, and TZ variable
- Easy-to-read format for quick comparison

**When to use:**
- Quick visual check of all container times
- Verifying timezone changes took effect
- Generating reports for documentation

**Example output:**
```
==========================================
Container Time Display - Simple View
==========================================

HOST TIME:
  Fri Feb 13 08:41:50 CST 2026
  Timezone: Europe/Berlin
  Timestamp: 1770993710

==========================================

CONTAINER TIMES:

CONTAINER NAME                                | DATE & TIME                         | TZ VARIABLE
----------------------------------------------|-------------------------------------|---------------------------
adempiere-ui-gateway.dictionary-rs            | Fri Feb 13 08:41:50 CST 2026        | Europe/Berlin
adempiere-ui-gateway.envoy-grpc-proxy         | Fri Feb 13 08:41:50 CST 2026        | Europe/Berlin
adempiere-ui-gateway.kafka                    | Fri Feb 13 08:41:51 CST 2026        | Europe/Berlin
adempiere-ui-gateway.postgresql               | Fri 13 Feb 2026 08:41:52 AM CST     | Europe/Berlin
...
```

---

## Database Backup Script

### 04-backup-database.sh

**Purpose:** Automated PostgreSQL database backup with compression and retention management.

**Usage:**
```bash
./04-backup-database.sh [backup-directory]
```

**What it does:**
- Creates timestamped backup files
- Compresses backups with gzip (~80% size reduction)
- Implements 30-day retention policy (automatic cleanup)
- Verifies container and database are running
- Provides detailed progress and statistics
- Calculates compression ratios

**When to use:**
- Manual database backups before major changes
- Automated daily backups (via cron or systemd timer)
- Creating backup before upgrades or migrations
- Regular backup routine for production systems

**Example output:**
```
==========================================
ADempiere Database Backup
==========================================
Date: Thu Feb 13 11:30:45 CST 2026
Database: adempiere
Container: adempiere-ui-gateway.postgresql

Creating backup...
✅ Backup created successfully: adempiere-2026-02-13-113045.backup
   Size: 245M

Compressing backup...
✅ Backup compressed: adempiere-2026-02-13-113045.backup.gz
   Compressed size: 45M
   Compression ratio: ~82%

Cleaning old backups (keeping last 30 days)...
📦 Backups remaining: 28

==========================================
✅ Backup completed successfully!
==========================================
```

**Scheduling automated backups:**

With cron (daily at 2 AM):
```bash
crontab -e
# Add:
0 2 * * * cd /path/to/docs/scripts && ./04-backup-database.sh >> /var/log/adempiere-backup.log 2>&1
```

See [Backup and Restore Guide](../backup-restore.md) for complete backup/restore documentation.

---

## Output Redirection

All scripts support output redirection to files:

```bash
# Save detailed report to file
./02-container-times-detailed.sh > timezone-report.txt

# Save simple view to file
./03-all-container-times-simple.sh > container-times.txt
```

The scripts automatically detect terminal vs. file output and adjust formatting accordingly (ANSI colors disabled when redirecting to files).

---

## Troubleshooting Common Issues

### Script shows "Permission denied"

Make scripts executable:
```bash
chmod +x *.sh
```

### Script shows "docker: command not found"

Ensure Docker is installed and in PATH:
```bash
docker --version
```

### Script shows fewer containers than expected

Check if all containers are running:
```bash
docker compose ps -a
```

The scripts only check **running** containers.

---

## Technical Details

### How Time Synchronization Works

- **Unix timestamps** are always stored in UTC internally
- **TZ environment variable** controls how time is displayed/formatted
- **Time difference = 0s** means clocks are synchronized (correct)
- Different display formats are cosmetic, not actual time differences

### Timezone Configuration Priority

Containers use this priority order for timezone:

1. **TZ environment variable** (highest priority, recommended)
2. **/etc/localtime** symlink or file
3. **/etc/timezone** file (lowest priority)

**Best practice:** Set TZ environment variable in docker-compose.yml:
```yaml
environment:
  TZ: ${GENERIC_TIMEZONE}
```

### Why Container Recreation is Required

Environment variables are set at **container creation time**, not runtime.

To apply TZ changes:
```bash
docker compose stop <service-name>
docker compose rm -f <service-name>
docker compose up -d <service-name>
```

Simply restarting (`docker compose restart`) will NOT apply environment variable changes.

---

## See Also

- [Troubleshooting Guide](../troubleshooting.md#timezone-mismatches) - Full timezone troubleshooting section
- [System Requirements](../system-requirements.md) - System requirements
- [Docker Compose Documentation](https://docs.docker.com/compose/) - Official Docker Compose docs

---

## Contributing

If you improve these scripts or find issues:
1. Test thoroughly with various container configurations
2. Ensure compatibility with file output redirection
3. Update this README with any changes
4. Submit improvements via pull request

---

**Last Updated:** 2026-02-13
**Maintainer:** ADempiere Community
