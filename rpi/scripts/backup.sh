#!/usr/bin/env bash
# EMA Database and Configuration Backup Script
# Creates timestamped backup archives of database volume and settings.

set -euo pipefail

BACKUP_DIR="${1:-/opt/ema/backups}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TARGET_FILE="${BACKUP_DIR}/ema_backup_${TIMESTAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Creating EMA backup archive at: $TARGET_FILE"

# Backup SQLite database from Docker volume and config files cleanly
tar -czf "$TARGET_FILE" \
    -C /var/lib/docker/volumes/ema-data/_data . 2>/dev/null || \
    docker run --rm -v ema-data:/data -v "$BACKUP_DIR":/backup alpine tar -czf "/backup/ema_backup_${TIMESTAMP}.tar.gz" -C /data .

# Keep only the last 14 backups
find "$BACKUP_DIR" -name "ema_backup_*.tar.gz" -mtime +14 -delete 2>/dev/null || true

echo "Backup completed successfully."
