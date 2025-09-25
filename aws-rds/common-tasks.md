# Common Tasks - Hướng Dẫn Chi Tiết

## 📅 **Daily Operations**

### **1. Monitor Database Performance**

#### **AWS CLI**
```bash
# Check CPU utilization
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name CPUUtilization \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 300 \
    --statistics Average

# Check database connections
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name DatabaseConnections \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 300 \
    --statistics Average
```

#### **PostgreSQL**
```sql
-- Check active connections
SELECT count(*) as active_connections 
FROM pg_stat_activity 
WHERE state = 'active';

-- Check database size
SELECT 
    datname,
    pg_size_pretty(pg_database_size(datname)) as size
FROM pg_database 
WHERE datname NOT IN ('template0', 'template1', 'postgres');

-- Check top queries by duration
SELECT 
    query,
    mean_exec_time,
    calls,
    total_exec_time
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 5;
```

#### **MySQL**
```sql
-- Check active connections
SELECT COUNT(*) as active_connections 
FROM INFORMATION_SCHEMA.PROCESSLIST 
WHERE COMMAND != 'Sleep';

-- Check database sizes
SELECT 
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables 
GROUP BY table_schema;

-- Check slow queries
SELECT 
    DIGEST_TEXT,
    COUNT_STAR as executions,
    AVG_TIMER_WAIT/1000000000 as avg_time_sec
FROM performance_schema.events_statements_summary_by_digest
ORDER BY AVG_TIMER_WAIT DESC
LIMIT 5;
```

### **2. Check Backup Status**

#### **AWS CLI**
```bash
# Check automated backup status
aws rds describe-db-instances \
    --db-instance-identifier your-db-instance \
    --query 'DBInstances[0].[BackupRetentionPeriod,PreferredBackupWindow]'

# List recent snapshots
aws rds describe-db-snapshots \
    --db-instance-identifier your-db-instance \
    --snapshot-type manual \
    --max-items 5

# Check latest automated backup
aws rds describe-db-instances \
    --db-instance-identifier your-db-instance \
    --query 'DBInstances[0].LatestRestorableTime'
```

### **3. Review Slow Queries**

#### **PostgreSQL**
```sql
-- Enable pg_stat_statements if not enabled
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Top 10 slowest queries
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    stddev_exec_time,
    rows
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;

-- Queries with high I/O
SELECT 
    query,
    shared_blks_read,
    shared_blks_hit,
    shared_blks_dirtied
FROM pg_stat_statements 
ORDER BY shared_blks_read DESC 
LIMIT 10;
```

#### **MySQL**
```sql
-- Check slow query log status
SHOW VARIABLES LIKE 'slow_query_log';
SHOW VARIABLES LIKE 'long_query_time';

-- Top queries by execution time
SELECT 
    DIGEST_TEXT,
    COUNT_STAR,
    AVG_TIMER_WAIT/1000000000 as avg_time_sec,
    MAX_TIMER_WAIT/1000000000 as max_time_sec
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT IS NOT NULL
ORDER BY AVG_TIMER_WAIT DESC
LIMIT 10;
```

### **4. Monitor Disk Space**

#### **AWS CLI**
```bash
# Check free storage space
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name FreeStorageSpace \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 300 \
    --statistics Average

# Check storage utilization
aws rds describe-db-instances \
    --db-instance-identifier your-db-instance \
    --query 'DBInstances[0].[AllocatedStorage,StorageType]'
```

## 📅 **Weekly Operations**

### **1. Update Statistics**

#### **PostgreSQL**
```sql
-- Update statistics for all tables
ANALYZE;

-- Update statistics for specific database
\c your_database
ANALYZE;

-- Check last analyze time
SELECT 
    schemaname,
    tablename,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY last_analyze DESC NULLS LAST;
```

#### **MySQL**
```sql
-- Analyze all tables in database
ANALYZE TABLE table1, table2, table3;

-- Or analyze all tables (run for each table)
SELECT CONCAT('ANALYZE TABLE ', table_name, ';') 
FROM information_schema.tables 
WHERE table_schema = 'your_database';
```

### **2. Review Security Logs**

#### **AWS CLI**
```bash
# Check security group rules
aws ec2 describe-security-groups \
    --group-ids sg-your-security-group \
    --query 'SecurityGroups[0].IpPermissions'

# Check parameter group settings
aws rds describe-db-parameters \
    --db-parameter-group-name your-parameter-group \
    --query 'Parameters[?ParameterName==`log_statement`]'
```

#### **PostgreSQL**
```sql
-- Check failed login attempts (if logging enabled)
-- This requires log_connections = on and log_disconnections = on

-- Check current connections by IP
SELECT 
    client_addr,
    count(*) as connections,
    array_agg(DISTINCT usename) as users
FROM pg_stat_activity 
WHERE client_addr IS NOT NULL
GROUP BY client_addr
ORDER BY connections DESC;

-- Check for suspicious activity
SELECT 
    usename,
    application_name,
    client_addr,
    state,
    query_start,
    query
FROM pg_stat_activity 
WHERE query NOT LIKE '%pg_stat_activity%'
    AND state = 'active';
```

### **3. Performance Tuning**

#### **PostgreSQL**
```sql
-- Check buffer hit ratio (should be > 99%)
SELECT 
    round(
        100.0 * sum(blks_hit) / (sum(blks_hit) + sum(blks_read)), 2
    ) as buffer_hit_ratio
FROM pg_stat_database;

-- Check index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_tup_read,
    idx_tup_fetch,
    idx_tup_read + idx_tup_fetch as total_index_access
FROM pg_stat_user_indexes
ORDER BY total_index_access DESC;

-- Find unused indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND indexname NOT LIKE '%_pkey';
```

#### **MySQL**
```sql
-- Check key buffer efficiency
SHOW STATUS LIKE 'Key_read%';
SHOW STATUS LIKE 'Key_write%';

-- Check InnoDB buffer pool hit ratio
SHOW STATUS LIKE 'Innodb_buffer_pool_read%';

-- Check table scan ratio
SHOW STATUS LIKE 'Handler_read%';
SHOW STATUS LIKE 'Select_scan';
```

### **4. Backup Verification**

#### **AWS CLI**
```bash
# Test restore from recent snapshot
aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier test-restore-$(date +%Y%m%d) \
    --db-snapshot-identifier your-latest-snapshot \
    --db-instance-class db.t3.micro

# Verify backup integrity (after restore)
# Connect to restored instance and run basic checks

# Clean up test instance
aws rds delete-db-instance \
    --db-instance-identifier test-restore-$(date +%Y%m%d) \
    --skip-final-snapshot
```

## 📅 **Monthly Operations**

### **1. Security Patches**

#### **AWS CLI**
```bash
# Check available engine versions
aws rds describe-db-engine-versions \
    --engine postgres \
    --query 'DBEngineVersions[?contains(SupportedEngineModes, `provisioned`)].EngineVersion'

# Check current engine version
aws rds describe-db-instances \
    --db-instance-identifier your-db-instance \
    --query 'DBInstances[0].EngineVersion'

# Schedule maintenance window
aws rds modify-db-instance \
    --db-instance-identifier your-db-instance \
    --preferred-maintenance-window sun:03:00-sun:04:00 \
    --apply-immediately
```

### **2. Capacity Planning**

#### **AWS CLI**
```bash
# Get storage metrics for last 30 days
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name FreeStorageSpace \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance \
    --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 86400 \
    --statistics Average,Minimum

# Get CPU metrics for last 30 days
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name CPUUtilization \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance \
    --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 86400 \
    --statistics Average,Maximum
```

#### **Database Growth Analysis**
```sql
-- PostgreSQL: Track database growth
SELECT 
    datname,
    pg_size_pretty(pg_database_size(datname)) as current_size,
    pg_database_size(datname) as size_bytes
FROM pg_database 
WHERE datname NOT IN ('template0', 'template1', 'postgres')
ORDER BY size_bytes DESC;

-- MySQL: Track database growth
SELECT 
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)',
    SUM(data_length + index_length) as size_bytes
FROM information_schema.tables 
GROUP BY table_schema
ORDER BY size_bytes DESC;
```

### **3. Cost Optimization**

#### **AWS CLI**
```bash
# Check instance utilization
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name CPUUtilization \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance \
    --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 3600 \
    --statistics Average,Maximum

# Check available reserved instances
aws rds describe-reserved-db-instances-offerings \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --query 'ReservedDBInstancesOfferings[0:5].[DBInstanceClass,Engine,Duration,FixedPrice]'

# Review storage type options
aws rds describe-db-instances \
    --db-instance-identifier your-db-instance \
    --query 'DBInstances[0].[StorageType,AllocatedStorage,Iops]'
```

### **4. Documentation Updates**

#### **Checklist**
- [ ] Update connection strings and endpoints
- [ ] Review and update backup procedures
- [ ] Update monitoring thresholds
- [ ] Review security configurations
- [ ] Update disaster recovery procedures
- [ ] Review and update user access permissions
- [ ] Update performance baseline metrics
- [ ] Review cost optimization opportunities

#### **Generate Documentation**
```bash
# Export current configuration
aws rds describe-db-instances \
    --db-instance-identifier your-db-instance \
    --output table > db-config-$(date +%Y%m%d).txt

# Export parameter group settings
aws rds describe-db-parameters \
    --db-parameter-group-name your-parameter-group \
    --output table > db-parameters-$(date +%Y%m%d).txt

# Export security group rules
aws ec2 describe-security-groups \
    --group-ids sg-your-security-group \
    --output table > security-groups-$(date +%Y%m%d).txt
```

## 🚨 **Emergency Procedures**

### **High CPU Usage**
```bash
# Immediate check
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name CPUUtilization \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 300 \
    --statistics Maximum
```

### **Storage Full**
```bash
# Check free space
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name FreeStorageSpace \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance \
    --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 300 \
    --statistics Minimum

# Emergency storage increase
aws rds modify-db-instance \
    --db-instance-identifier your-db-instance \
    --allocated-storage 100 \
    --apply-immediately
```

### **Connection Issues**
```sql
-- PostgreSQL: Check connections
SELECT 
    count(*) as total_connections,
    count(*) FILTER (WHERE state = 'active') as active_connections
FROM pg_stat_activity;

-- MySQL: Check connections
SELECT 
    COUNT(*) as total_connections,
    COUNT(*) - SUM(CASE WHEN COMMAND = 'Sleep' THEN 1 ELSE 0 END) as active_connections
FROM INFORMATION_SCHEMA.PROCESSLIST;
```