-- PostgreSQL Maintenance Queries
-- Common maintenance and monitoring queries for PostgreSQL RDS

-- ============================================================================
-- DATABASE SIZE AND USAGE
-- ============================================================================

-- Database sizes
SELECT 
    datname as database_name,
    pg_size_pretty(pg_database_size(datname)) as size,
    pg_database_size(datname) as size_bytes
FROM pg_database 
WHERE datistemplate = false
ORDER BY pg_database_size(datname) DESC;

-- Table sizes in current database
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as index_size,
    pg_total_relation_size(schemaname||'.'||tablename) as total_bytes
FROM pg_tables 
WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- ============================================================================
-- CONNECTION MONITORING
-- ============================================================================

-- Current active connections
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    client_port,
    backend_start,
    state,
    state_change,
    query_start,
    now() - query_start as query_duration,
    query
FROM pg_stat_activity 
WHERE state != 'idle'
ORDER BY query_start;

-- Connection summary by state
SELECT 
    state,
    count(*) as connections
FROM pg_stat_activity 
GROUP BY state
ORDER BY connections DESC;

-- Connection summary by database
SELECT 
    datname,
    count(*) as connections,
    count(*) FILTER (WHERE state = 'active') as active_connections
FROM pg_stat_activity 
GROUP BY datname
ORDER BY connections DESC;

-- ============================================================================
-- PERFORMANCE MONITORING
-- ============================================================================

-- Long running queries (> 5 minutes)
SELECT 
    pid,
    usename,
    datname,
    now() - query_start as duration,
    state,
    query
FROM pg_stat_activity 
WHERE state = 'active' 
    AND now() - query_start > interval '5 minutes'
ORDER BY duration DESC;

-- Blocking queries
SELECT 
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;

-- ============================================================================
-- TABLE STATISTICS
-- ============================================================================

-- Table activity statistics
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_tuples,
    n_dead_tup as dead_tuples,
    CASE 
        WHEN n_live_tup > 0 
        THEN round((n_dead_tup::float / n_live_tup::float) * 100, 2)
        ELSE 0 
    END as dead_tuple_percent,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY dead_tuple_percent DESC;

-- Tables needing vacuum (high dead tuple ratio)
SELECT 
    schemaname,
    tablename,
    n_live_tup as live_tuples,
    n_dead_tup as dead_tuples,
    round((n_dead_tup::float / n_live_tup::float) * 100, 2) as dead_tuple_percent,
    last_autovacuum
FROM pg_stat_user_tables
WHERE n_live_tup > 0 
    AND (n_dead_tup::float / n_live_tup::float) > 0.1
ORDER BY dead_tuple_percent DESC;

-- ============================================================================
-- INDEX USAGE
-- ============================================================================

-- Index usage statistics
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
ORDER BY idx_tup_read DESC;

-- Unused indexes (never used for reads)
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE idx_tup_read = 0 AND idx_tup_fetch = 0
ORDER BY pg_relation_size(indexrelid) DESC;

-- Missing indexes (tables with sequential scans)
SELECT 
    schemaname,
    tablename,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    n_live_tup,
    CASE 
        WHEN seq_scan > 0 
        THEN round((seq_tup_read::float / seq_scan::float), 2)
        ELSE 0 
    END as avg_seq_read
FROM pg_stat_user_tables
WHERE seq_scan > 0 
    AND n_live_tup > 1000
    AND (idx_scan IS NULL OR seq_scan > idx_scan)
ORDER BY seq_tup_read DESC;

-- ============================================================================
-- VACUUM AND ANALYZE STATUS
-- ============================================================================

-- Vacuum and analyze history
SELECT 
    schemaname,
    tablename,
    last_vacuum,
    last_autovacuum,
    vacuum_count,
    autovacuum_count,
    last_analyze,
    last_autoanalyze,
    analyze_count,
    autoanalyze_count
FROM pg_stat_user_tables
ORDER BY last_autovacuum DESC NULLS LAST;

-- Tables that haven't been vacuumed recently
SELECT 
    schemaname,
    tablename,
    last_vacuum,
    last_autovacuum,
    n_dead_tup,
    CASE 
        WHEN last_autovacuum IS NOT NULL 
        THEN extract(epoch from (now() - last_autovacuum))/3600 
        ELSE NULL 
    END as hours_since_vacuum
FROM pg_stat_user_tables
WHERE (last_autovacuum IS NULL OR last_autovacuum < now() - interval '24 hours')
    AND n_dead_tup > 1000
ORDER BY n_dead_tup DESC;

-- ============================================================================
-- REPLICATION STATUS (if applicable)
-- ============================================================================

-- Replication slots
SELECT 
    slot_name,
    plugin,
    slot_type,
    datoid,
    database,
    active,
    active_pid,
    xmin,
    catalog_xmin,
    restart_lsn,
    confirmed_flush_lsn
FROM pg_replication_slots;

-- Replication lag (if read replica)
SELECT 
    client_addr,
    client_hostname,
    client_port,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    write_lag,
    flush_lag,
    replay_lag,
    sync_state
FROM pg_stat_replication;

-- ============================================================================
-- CONFIGURATION CHECK
-- ============================================================================

-- Important configuration parameters
SELECT 
    name,
    setting,
    unit,
    context,
    source
FROM pg_settings 
WHERE name IN (
    'shared_buffers',
    'work_mem',
    'maintenance_work_mem',
    'effective_cache_size',
    'checkpoint_completion_target',
    'wal_buffers',
    'max_connections',
    'log_min_duration_statement',
    'log_checkpoints',
    'log_lock_waits',
    'log_temp_files'
)
ORDER BY name;

-- ============================================================================
-- MAINTENANCE COMMANDS
-- ============================================================================

-- Generate VACUUM commands for tables with high dead tuple ratio
SELECT 
    'VACUUM ANALYZE ' || schemaname || '.' || tablename || ';' as vacuum_command
FROM pg_stat_user_tables
WHERE n_live_tup > 0 
    AND (n_dead_tup::float / n_live_tup::float) > 0.1
ORDER BY (n_dead_tup::float / n_live_tup::float) DESC;

-- Generate REINDEX commands for bloated indexes
SELECT 
    'REINDEX INDEX CONCURRENTLY ' || schemaname || '.' || indexname || ';' as reindex_command
FROM pg_stat_user_indexes
WHERE idx_tup_read > 0
ORDER BY pg_relation_size(indexrelid) DESC;

-- ============================================================================
-- SECURITY MONITORING
-- ============================================================================

-- List all users and their privileges
SELECT 
    rolname,
    rolsuper,
    rolinherit,
    rolcreaterole,
    rolcreatedb,
    rolcanlogin,
    rolreplication,
    rolconnlimit,
    rolvaliduntil
FROM pg_roles
ORDER BY rolname;

-- Database permissions
SELECT 
    d.datname,
    r.rolname,
    has_database_privilege(r.rolname, d.datname, 'CONNECT') as can_connect,
    has_database_privilege(r.rolname, d.datname, 'CREATE') as can_create
FROM pg_database d
CROSS JOIN pg_roles r
WHERE d.datistemplate = false
    AND r.rolcanlogin = true
ORDER BY d.datname, r.rolname;