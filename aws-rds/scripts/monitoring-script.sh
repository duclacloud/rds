#!/bin/bash

# RDS Monitoring Script
# Usage: ./monitoring-script.sh [instance-identifier]

set -e

# Configuration
THRESHOLD_CPU=80
THRESHOLD_CONNECTIONS=80
THRESHOLD_FREESPACE=20

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check parameters
if [ $# -lt 1 ]; then
    error "Usage: $0 [instance-identifier]"
    exit 1
fi

INSTANCE_ID=$1

# Get instance information
log "Checking RDS instance: $INSTANCE_ID"

INSTANCE_INFO=$(aws rds describe-db-instances \
    --db-instance-identifier "$INSTANCE_ID" \
    --query 'DBInstances[0]' \
    --output json)

if [ "$INSTANCE_INFO" = "null" ]; then
    error "Instance $INSTANCE_ID not found"
    exit 1
fi

# Extract instance details
ENGINE=$(echo "$INSTANCE_INFO" | jq -r '.Engine')
STATUS=$(echo "$INSTANCE_INFO" | jq -r '.DBInstanceStatus')
ENDPOINT=$(echo "$INSTANCE_INFO" | jq -r '.Endpoint.Address')
CLASS=$(echo "$INSTANCE_INFO" | jq -r '.DBInstanceClass')

info "Engine: $ENGINE"
info "Status: $STATUS"
info "Endpoint: $ENDPOINT"
info "Instance Class: $CLASS"

# Check instance status
if [ "$STATUS" != "available" ]; then
    warning "Instance status is not 'available': $STATUS"
fi

# Get CloudWatch metrics
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)
START_TIME=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)

log "Fetching CloudWatch metrics..."

# CPU Utilization
CPU_UTIL=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name CPUUtilization \
    --dimensions Name=DBInstanceIdentifier,Value="$INSTANCE_ID" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 300 \
    --statistics Average \
    --query 'Datapoints[0].Average' \
    --output text)

if [ "$CPU_UTIL" != "None" ]; then
    CPU_UTIL_INT=$(printf "%.0f" "$CPU_UTIL")
    if [ "$CPU_UTIL_INT" -gt "$THRESHOLD_CPU" ]; then
        warning "High CPU utilization: ${CPU_UTIL}%"
    else
        info "CPU utilization: ${CPU_UTIL}%"
    fi
else
    warning "No CPU utilization data available"
fi

# Database Connections
DB_CONNECTIONS=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name DatabaseConnections \
    --dimensions Name=DBInstanceIdentifier,Value="$INSTANCE_ID" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 300 \
    --statistics Average \
    --query 'Datapoints[0].Average' \
    --output text)

if [ "$DB_CONNECTIONS" != "None" ]; then
    info "Database connections: $DB_CONNECTIONS"
else
    warning "No connection data available"
fi

# Free Storage Space
FREE_SPACE=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name FreeStorageSpace \
    --dimensions Name=DBInstanceIdentifier,Value="$INSTANCE_ID" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 300 \
    --statistics Average \
    --query 'Datapoints[0].Average' \
    --output text)

if [ "$FREE_SPACE" != "None" ]; then
    FREE_SPACE_GB=$(echo "scale=2; $FREE_SPACE / 1024 / 1024 / 1024" | bc)
    info "Free storage space: ${FREE_SPACE_GB} GB"
    
    # Check if free space is below threshold (assuming 100GB total for calculation)
    FREE_SPACE_PERCENT=$(echo "scale=0; $FREE_SPACE_GB * 100 / 100" | bc)
    if [ "$FREE_SPACE_PERCENT" -lt "$THRESHOLD_FREESPACE" ]; then
        warning "Low free storage space: ${FREE_SPACE_GB} GB"
    fi
else
    warning "No storage space data available"
fi

# Read/Write IOPS
READ_IOPS=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name ReadIOPS \
    --dimensions Name=DBInstanceIdentifier,Value="$INSTANCE_ID" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 300 \
    --statistics Average \
    --query 'Datapoints[0].Average' \
    --output text)

WRITE_IOPS=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name WriteIOPS \
    --dimensions Name=DBInstanceIdentifier,Value="$INSTANCE_ID" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 300 \
    --statistics Average \
    --query 'Datapoints[0].Average' \
    --output text)

if [ "$READ_IOPS" != "None" ]; then
    info "Read IOPS: $READ_IOPS"
fi

if [ "$WRITE_IOPS" != "None" ]; then
    info "Write IOPS: $WRITE_IOPS"
fi

# Database-specific checks
case $ENGINE in
    "postgres")
        log "PostgreSQL specific checks..."
        
        if [ -n "$POSTGRES_USER" ] && [ -n "$POSTGRES_PASSWORD" ]; then
            # Check active connections
            ACTIVE_CONN=$(PGPASSWORD="$POSTGRES_PASSWORD" psql \
                -h "$ENDPOINT" \
                -U "$POSTGRES_USER" \
                -d "$POSTGRES_DB" \
                -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null || echo "0")
            
            info "Active PostgreSQL connections: $ACTIVE_CONN"
            
            # Check for long running queries
            LONG_QUERIES=$(PGPASSWORD="$POSTGRES_PASSWORD" psql \
                -h "$ENDPOINT" \
                -U "$POSTGRES_USER" \
                -d "$POSTGRES_DB" \
                -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active' AND now() - query_start > interval '5 minutes';" 2>/dev/null || echo "0")
            
            if [ "$LONG_QUERIES" -gt 0 ]; then
                warning "Long running queries detected: $LONG_QUERIES"
            fi
        fi
        ;;
        
    "mysql")
        log "MySQL specific checks..."
        
        if [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ]; then
            # Check active connections
            ACTIVE_CONN=$(mysql \
                -h "$ENDPOINT" \
                -u "$MYSQL_USER" \
                -p"$MYSQL_PASSWORD" \
                -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.PROCESSLIST WHERE COMMAND != 'Sleep';" \
                -s -N 2>/dev/null || echo "0")
            
            info "Active MySQL connections: $ACTIVE_CONN"
            
            # Check for long running queries
            LONG_QUERIES=$(mysql \
                -h "$ENDPOINT" \
                -u "$MYSQL_USER" \
                -p"$MYSQL_PASSWORD" \
                -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.PROCESSLIST WHERE TIME > 300 AND COMMAND != 'Sleep';" \
                -s -N 2>/dev/null || echo "0")
            
            if [ "$LONG_QUERIES" -gt 0 ]; then
                warning "Long running queries detected: $LONG_QUERIES"
            fi
        fi
        ;;
esac

# Check recent events
log "Checking recent events..."
RECENT_EVENTS=$(aws rds describe-events \
    --source-identifier "$INSTANCE_ID" \
    --source-type db-instance \
    --start-time "$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S)" \
    --query 'Events[*].[Date,Message]' \
    --output text)

if [ -n "$RECENT_EVENTS" ]; then
    info "Recent events:"
    echo "$RECENT_EVENTS"
else
    info "No recent events"
fi

log "Monitoring check completed for $INSTANCE_ID"