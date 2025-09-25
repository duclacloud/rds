#!/bin/bash

# RDS Backup Automation Script
# Usage: ./backup-script.sh [postgres|mysql] [instance-identifier]

set -e

# Configuration
BACKUP_DIR="/backup/rds"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Check parameters
if [ $# -lt 2 ]; then
    error "Usage: $0 [postgres|mysql] [instance-identifier]"
    exit 1
fi

DB_TYPE=$1
INSTANCE_ID=$2

# Create backup directory
mkdir -p "$BACKUP_DIR/$DB_TYPE"

case $DB_TYPE in
    "postgres")
        log "Starting PostgreSQL backup for $INSTANCE_ID"
        
        # Get RDS endpoint
        ENDPOINT=$(aws rds describe-db-instances \
            --db-instance-identifier "$INSTANCE_ID" \
            --query 'DBInstances[0].Endpoint.Address' \
            --output text)
        
        if [ "$ENDPOINT" = "None" ]; then
            error "Instance $INSTANCE_ID not found"
            exit 1
        fi
        
        # Create AWS snapshot
        log "Creating AWS snapshot..."
        SNAPSHOT_ID="${INSTANCE_ID}-snapshot-${DATE}"
        aws rds create-db-snapshot \
            --db-instance-identifier "$INSTANCE_ID" \
            --db-snapshot-identifier "$SNAPSHOT_ID"
        
        # Logical backup (if credentials available)
        if [ -n "$POSTGRES_USER" ] && [ -n "$POSTGRES_PASSWORD" ]; then
            log "Creating logical backup..."
            BACKUP_FILE="$BACKUP_DIR/$DB_TYPE/${INSTANCE_ID}_${DATE}.sql.gz"
            
            PGPASSWORD="$POSTGRES_PASSWORD" pg_dump \
                -h "$ENDPOINT" \
                -U "$POSTGRES_USER" \
                -d "$POSTGRES_DB" \
                --no-password \
                | gzip > "$BACKUP_FILE"
            
            log "Logical backup saved: $BACKUP_FILE"
        fi
        ;;
        
    "mysql")
        log "Starting MySQL backup for $INSTANCE_ID"
        
        # Get RDS endpoint
        ENDPOINT=$(aws rds describe-db-instances \
            --db-instance-identifier "$INSTANCE_ID" \
            --query 'DBInstances[0].Endpoint.Address' \
            --output text)
        
        if [ "$ENDPOINT" = "None" ]; then
            error "Instance $INSTANCE_ID not found"
            exit 1
        fi
        
        # Create AWS snapshot
        log "Creating AWS snapshot..."
        SNAPSHOT_ID="${INSTANCE_ID}-snapshot-${DATE}"
        aws rds create-db-snapshot \
            --db-instance-identifier "$INSTANCE_ID" \
            --db-snapshot-identifier "$SNAPSHOT_ID"
        
        # Logical backup (if credentials available)
        if [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ]; then
            log "Creating logical backup..."
            BACKUP_FILE="$BACKUP_DIR/$DB_TYPE/${INSTANCE_ID}_${DATE}.sql.gz"
            
            mysqldump \
                -h "$ENDPOINT" \
                -u "$MYSQL_USER" \
                -p"$MYSQL_PASSWORD" \
                --single-transaction \
                --routines \
                --triggers \
                "$MYSQL_DB" \
                | gzip > "$BACKUP_FILE"
            
            log "Logical backup saved: $BACKUP_FILE"
        fi
        ;;
        
    *)
        error "Unsupported database type: $DB_TYPE"
        exit 1
        ;;
esac

# Cleanup old backups
log "Cleaning up old backups (older than $RETENTION_DAYS days)..."
find "$BACKUP_DIR/$DB_TYPE" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete

# Cleanup old snapshots
log "Cleaning up old snapshots..."
OLD_SNAPSHOTS=$(aws rds describe-db-snapshots \
    --db-instance-identifier "$INSTANCE_ID" \
    --snapshot-type manual \
    --query "DBSnapshots[?SnapshotCreateTime<='$(date -d "$RETENTION_DAYS days ago" -u +%Y-%m-%dT%H:%M:%S.000Z)'].DBSnapshotIdentifier" \
    --output text)

for snapshot in $OLD_SNAPSHOTS; do
    if [ "$snapshot" != "None" ]; then
        log "Deleting old snapshot: $snapshot"
        aws rds delete-db-snapshot --db-snapshot-identifier "$snapshot"
    fi
done

log "Backup completed successfully!"