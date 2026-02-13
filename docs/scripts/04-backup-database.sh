#!/bin/bash
#
# ADempiere Database Backup Script
#
# Purpose: Automated backup of PostgreSQL database with compression and retention
# Usage: ./backup-database.sh [backup-directory]
#
# Features:
# - Creates timestamped backup files
# - Compresses backups with gzip
# - Implements retention policy (default 30 days)
# - Provides detailed progress output
#
# Location: docs/scripts/backup-database.sh
# Project: ADempiere UI Gateway
# Date: 2026-02-13

set -e

# ==========================================
# Configuration
# ==========================================

# Default backup directory (relative to docker-compose/)
DEFAULT_BACKUP_DIR="../../docker-compose/postgresql/postgres_backups"

# Use provided directory or default
if [ -n "$1" ]; then
  BACKUP_DIR="$1"
else
  BACKUP_DIR="$DEFAULT_BACKUP_DIR"
fi

# Container and database configuration
CONTAINER_NAME="adempiere-ui-gateway.postgresql"
DB_NAME="adempiere"
DB_USER="postgres"

# Retention policy (days)
RETENTION_DAYS=30

# ==========================================
# Script Start
# ==========================================

echo "=========================================="
echo "ADempiere Database Backup"
echo "=========================================="
echo "Date: $(date)"
echo "Database: $DB_NAME"
echo "Container: $CONTAINER_NAME"
echo "Backup directory: $BACKUP_DIR"
echo ""

# Create backup directory if not exists
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date '+%Y-%m-%d-%H%M%S')
BACKUP_FILE="$BACKUP_DIR/adempiere-$TIMESTAMP.backup"

# Check if container is running
if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
  echo "❌ ERROR: Container $CONTAINER_NAME is not running!"
  echo "   Please start the stack first with: ./start-all.sh"
  exit 1
fi

# Check if database exists
if ! docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
  echo "❌ ERROR: Database $DB_NAME does not exist in container!"
  exit 1
fi

# Create backup
echo "Creating backup..."
docker exec -i "$CONTAINER_NAME" pg_dump \
  --no-owner \
  -h localhost \
  -U "$DB_USER" \
  "$DB_NAME" > "$BACKUP_FILE"

# Verify backup was created
if [ ! -f "$BACKUP_FILE" ]; then
  echo "❌ ERROR: Backup file not created!"
  exit 1
fi

SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "✅ Backup created successfully: $BACKUP_FILE"
echo "   Size: $SIZE"

# Compress backup
echo ""
echo "Compressing backup..."
gzip "$BACKUP_FILE"
COMPRESSED_FILE="$BACKUP_FILE.gz"

if [ ! -f "$COMPRESSED_FILE" ]; then
  echo "❌ ERROR: Compression failed!"
  exit 1
fi

COMPRESSED_SIZE=$(du -h "$COMPRESSED_FILE" | cut -f1)
ORIGINAL_SIZE=$(echo "$SIZE" | sed 's/[^0-9.]//g')
COMPRESSED_SIZE_NUM=$(echo "$COMPRESSED_SIZE" | sed 's/[^0-9.]//g')

echo "✅ Backup compressed: $COMPRESSED_FILE"
echo "   Compressed size: $COMPRESSED_SIZE"

# Calculate compression ratio if possible
if [ -n "$ORIGINAL_SIZE" ] && [ -n "$COMPRESSED_SIZE_NUM" ]; then
  echo "   Compression ratio: ~$(echo "scale=0; 100 - ($COMPRESSED_SIZE_NUM / $ORIGINAL_SIZE * 100)" | bc)%"
fi

# Remove old backups (keep last N days)
echo ""
echo "Cleaning old backups (keeping last $RETENTION_DAYS days)..."
DELETED=$(find "$BACKUP_DIR" -name "adempiere-*.backup.gz" -mtime +$RETENTION_DAYS -type f -delete -print | wc -l)

if [ "$DELETED" -gt 0 ]; then
  echo "🗑️  Deleted $DELETED old backup(s)"
fi

REMAINING=$(find "$BACKUP_DIR" -name "adempiere-*.backup.gz" -type f | wc -l)
echo "📦 Backups remaining: $REMAINING"

# Show disk usage
echo ""
echo "Backup directory disk usage:"
du -sh "$BACKUP_DIR"

echo ""
echo "=========================================="
echo "✅ Backup completed successfully!"
echo "=========================================="
echo ""
echo "Backup file: $COMPRESSED_FILE"
echo ""
echo "To restore this backup, see:"
echo "  docs/backup-restore.md#database-restore-procedures"
echo ""
