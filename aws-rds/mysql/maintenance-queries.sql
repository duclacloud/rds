-- MySQL Maintenance Queries
-- Common maintenance and monitoring queries for MySQL RDS

-- ============================================================================
-- DATABASE SIZE AND USAGE
-- ============================================================================

-- Database sizes
SELECT 
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)',
    ROUND(SUM(data_length) / 1024 / 1024, 2) AS 'Data (MB)',
    ROUND(SUM(index_length) / 1024 / 1024, 2) AS 'Index (MB)'
FROM information_schema.tables 
WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
GROUP BY table_schema
ORDER BY SUM(data_length + index_length) DESC;

-- Table sizes in current database
SELECT 
    table_name,
    table_rows,
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Total Size (MB)',
    ROUND((data_length / 1024 / 1024), 2) AS 'Data Size (MB)',
    ROUND((index_length / 1024 / 1024), 2) AS 'Index Size (MB)',
    ROUND((data_free / 1024 / 1024), 2) AS 'Free Space (MB)'
FROM information_schema.tables 
WHERE table_schema = DATABASE()
ORDER BY (data_length + index_length) DESC;

-- ============================================================================
-- CONNECTION MONITORING
-- ============================================================================

-- Current active connections
SELECT 
    ID,
    USER,
    HOST,
    DB,
    COMMAND,
    TIME,
    STATE,
    LEFT(INFO, 100) AS QUERY_PREVIEW
FROM INFORMATION_SCHEMA.PROCESSLIST
WHERE COMMAND != 'Sleep'
ORDER BY TIME DESC;

-- Connection summary by state
SELECT 
    COMMAND,
    COUNT(*) as connections
FROM INFORMATION_SCHEMA.PROCESSLIST
GROUP BY COMMAND
ORDER BY connections DESC;

-- Connection summary by user
SELECT 
    USER,
    COUNT(*) as connections,
    COUNT(CASE WHEN COMMAND != 'Sleep' THEN 1 END) as active_connections
FROM INFORMATION_SCHEMA.PROCESSLIST
GROUP BY USER
ORDER BY connections DESC;

-- Connection summary by database
SELECT 
    DB,
    COUNT(*) as connections,
    COUNT(CASE WHEN COMMAND != 'Sleep' THEN 1 END) as active_connections
FROM INFORMATION_SCHEMA.PROCESSLIST
WHERE DB IS NOT NULL
GROUP BY DB
ORDER BY connections DESC;

-- ============================================================================
-- PERFORMANCE MONITORING
-- ============================================================================

-- Long running queries (> 300 seconds)
SELECT 
    ID,
    USER,
    HOST,
    DB,
    TIME as duration_seconds,
    STATE,
    INFO as query
FROM INFORMATION_SCHEMA.PROCESSLIST
WHERE TIME > 300 AND COMMAND != 'Sleep'
ORDER BY TIME DESC;

-- Performance Schema - Top queries by execution time
SELECT 
    DIGEST_TEXT,
    COUNT_STAR as executions,
    ROUND(AVG_TIMER_WAIT/1000000000, 2) as avg_time_sec,
    ROUND(SUM_TIMER_WAIT/1000000000, 2) as total_time_sec,
    ROUND(MIN_TIMER_WAIT/1000000000, 2) as min_time_sec,
    ROUND(MAX_TIMER_WAIT/1000000000, 2) as max_time_sec
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT IS NOT NULL
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 20;

-- Performance Schema - Table I/O statistics
SELECT 
    OBJECT_SCHEMA,
    OBJECT_NAME,
    COUNT_READ,
    COUNT_WRITE,
    COUNT_FETCH,
    COUNT_INSERT,
    COUNT_UPDATE,
    COUNT_DELETE,
    ROUND(SUM_TIMER_WAIT/1000000000, 2) as total_time_sec
FROM performance_schema.table_io_waits_summary_by_table
WHERE OBJECT_SCHEMA NOT IN ('mysql', 'performance_schema', 'information_schema', 'sys')
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 20;

-- ============================================================================
-- TABLE STATISTICS
-- ============================================================================

-- InnoDB table statistics
SELECT 
    table_schema,
    table_name,
    table_rows,
    avg_row_length,
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS 'Total Size (MB)',
    ROUND(data_free / 1024 / 1024, 2) AS 'Free Space (MB)',
    engine,
    table_collation,
    create_time,
    update_time
FROM information_schema.tables 
WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND engine = 'InnoDB'
ORDER BY (data_length + index_length) DESC;

-- Tables with fragmentation (free space)
SELECT 
    table_schema,
    table_name,
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS 'Total Size (MB)',
    ROUND(data_free / 1024 / 1024, 2) AS 'Free Space (MB)',
    ROUND((data_free / (data_length + index_length)) * 100, 2) AS 'Fragmentation %'
FROM information_schema.tables 
WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND data_free > 0
    AND (data_length + index_length) > 0
ORDER BY (data_free / (data_length + index_length)) DESC;

-- ============================================================================
-- INDEX USAGE
-- ============================================================================

-- Index statistics
SELECT 
    TABLE_SCHEMA,
    TABLE_NAME,
    INDEX_NAME,
    CARDINALITY,
    CASE 
        WHEN NON_UNIQUE = 0 THEN 'UNIQUE'
        ELSE 'NON-UNIQUE'
    END AS index_type,
    COLUMN_NAME,
    SEQ_IN_INDEX
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
ORDER BY TABLE_SCHEMA, TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;

-- Unused indexes (Performance Schema required)
SELECT 
    object_schema,
    object_name,
    index_name
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE index_name IS NOT NULL
    AND index_name != 'PRIMARY'
    AND count_star = 0
    AND object_schema NOT IN ('mysql', 'performance_schema', 'information_schema', 'sys')
ORDER BY object_schema, object_name;

-- Index usage statistics (Performance Schema required)
SELECT 
    object_schema,
    object_name,
    index_name,
    count_fetch,
    count_insert,
    count_update,
    count_delete,
    ROUND(sum_timer_fetch/1000000000, 2) as fetch_time_sec
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE object_schema NOT IN ('mysql', 'performance_schema', 'information_schema', 'sys')
    AND index_name IS NOT NULL
ORDER BY count_fetch DESC;

-- ============================================================================
-- INNODB STATUS
-- ============================================================================

-- InnoDB buffer pool usage
SELECT 
    POOL_ID,
    POOL_SIZE,
    FREE_BUFFERS,
    DATABASE_PAGES,
    OLD_DATABASE_PAGES,
    MODIFIED_DATABASE_PAGES,
    PENDING_DECOMPRESS,
    PENDING_READS,
    PENDING_FLUSH_LRU,
    PENDING_FLUSH_LIST,
    PAGES_MADE_YOUNG,
    PAGES_NOT_MADE_YOUNG,
    PAGES_MADE_YOUNG_RATE,
    PAGES_MADE_NOT_YOUNG_RATE,
    NUMBER_PAGES_READ,
    NUMBER_PAGES_CREATED,
    NUMBER_PAGES_WRITTEN,
    PAGES_READ_RATE,
    PAGES_CREATE_RATE,
    PAGES_WRITTEN_RATE,
    NUMBER_PAGES_GET,
    HIT_RATE,
    YOUNG_MAKE_PER_THOUSAND_GETS,
    NOT_YOUNG_MAKE_PER_THOUSAND_GETS,
    NUMBER_PAGES_READ_AHEAD,
    NUMBER_READ_AHEAD_EVICTED,
    READ_AHEAD_RATE,
    READ_AHEAD_EVICTED_RATE,
    LRU_IO_TOTAL,
    LRU_IO_CURRENT,
    UNCOMPRESS_TOTAL,
    UNCOMPRESS_CURRENT
FROM INFORMATION_SCHEMA.INNODB_BUFFER_POOL_STATS;

-- InnoDB transactions
SELECT 
    trx_id,
    trx_state,
    trx_started,
    trx_requested_lock_id,
    trx_wait_started,
    trx_weight,
    trx_mysql_thread_id,
    trx_query,
    trx_operation_state,
    trx_tables_in_use,
    trx_tables_locked,
    trx_lock_structs,
    trx_lock_memory_bytes,
    trx_rows_locked,
    trx_rows_modified,
    trx_concurrency_tickets,
    trx_isolation_level,
    trx_unique_checks,
    trx_foreign_key_checks,
    trx_last_foreign_key_error,
    trx_adaptive_hash_latched,
    trx_adaptive_hash_timeout,
    trx_is_read_only,
    trx_autocommit_non_locking
FROM INFORMATION_SCHEMA.INNODB_TRX;

-- ============================================================================
-- REPLICATION STATUS
-- ============================================================================

-- Master status
SHOW MASTER STATUS;

-- Slave status (use \G for vertical display)
-- SHOW SLAVE STATUS\G

-- Binary log files
SHOW BINARY LOGS;

-- Relay log info (for slaves)
SELECT 
    CHANNEL_NAME,
    HOST,
    PORT,
    USER,
    SOURCE_LOG_FILE,
    READ_MASTER_LOG_POS,
    RELAY_LOG_FILE,
    RELAY_LOG_POS,
    RELAY_MASTER_LOG_FILE,
    SLAVE_IO_RUNNING,
    SLAVE_SQL_RUNNING,
    REPLICATE_DO_DB,
    REPLICATE_IGNORE_DB,
    REPLICATE_DO_TABLE,
    REPLICATE_IGNORE_TABLE,
    REPLICATE_WILD_DO_TABLE,
    REPLICATE_WILD_IGNORE_TABLE,
    LAST_ERRNO,
    LAST_ERROR,
    SKIP_COUNTER,
    EXEC_MASTER_LOG_POS,
    RELAY_LOG_SPACE,
    UNTIL_CONDITION,
    UNTIL_LOG_FILE,
    UNTIL_LOG_POS,
    MASTER_SSL_ALLOWED,
    MASTER_SSL_CA_FILE,
    MASTER_SSL_CA_PATH,
    MASTER_SSL_CERT,
    MASTER_SSL_CIPHER,
    MASTER_SSL_KEY,
    SECONDS_BEHIND_MASTER,
    MASTER_SSL_VERIFY_SERVER_CERT,
    LAST_IO_ERRNO,
    LAST_IO_ERROR,
    LAST_SQL_ERRNO,
    LAST_SQL_ERROR,
    REPLICATE_IGNORE_SERVER_IDS,
    MASTER_SERVER_ID,
    MASTER_UUID,
    MASTER_INFO_FILE,
    SQL_DELAY,
    SQL_REMAINING_DELAY,
    SLAVE_SQL_RUNNING_STATE,
    MASTER_RETRY_COUNT,
    MASTER_BIND,
    LAST_IO_ERROR_TIMESTAMP,
    LAST_SQL_ERROR_TIMESTAMP,
    MASTER_SSL_CRL,
    MASTER_SSL_CRLPATH,
    RETRIEVED_GTID_SET,
    EXECUTED_GTID_SET,
    AUTO_POSITION,
    REPLICATE_REWRITE_DB,
    CHANNEL_NAME as CHANNEL,
    MASTER_TLS_VERSION
FROM performance_schema.replication_connection_status rcs
JOIN performance_schema.replication_applier_status_by_coordinator rasc 
    ON rcs.CHANNEL_NAME = rasc.CHANNEL_NAME;

-- ============================================================================
-- CONFIGURATION CHECK
-- ============================================================================

-- Important configuration variables
SELECT 
    VARIABLE_NAME,
    VARIABLE_VALUE
FROM performance_schema.global_variables 
WHERE VARIABLE_NAME IN (
    'innodb_buffer_pool_size',
    'innodb_log_file_size',
    'innodb_flush_log_at_trx_commit',
    'sync_binlog',
    'max_connections',
    'query_cache_size',
    'query_cache_type',
    'tmp_table_size',
    'max_heap_table_size',
    'key_buffer_size',
    'sort_buffer_size',
    'read_buffer_size',
    'read_rnd_buffer_size',
    'join_buffer_size',
    'thread_cache_size',
    'table_open_cache',
    'slow_query_log',
    'long_query_time',
    'log_queries_not_using_indexes'
)
ORDER BY VARIABLE_NAME;

-- Status variables
SELECT 
    VARIABLE_NAME,
    VARIABLE_VALUE
FROM performance_schema.global_status 
WHERE VARIABLE_NAME IN (
    'Connections',
    'Max_used_connections',
    'Threads_connected',
    'Threads_running',
    'Uptime',
    'Questions',
    'Queries',
    'Slow_queries',
    'Com_select',
    'Com_insert',
    'Com_update',
    'Com_delete',
    'Innodb_buffer_pool_read_requests',
    'Innodb_buffer_pool_reads',
    'Innodb_buffer_pool_pages_total',
    'Innodb_buffer_pool_pages_free',
    'Innodb_buffer_pool_pages_dirty',
    'Key_reads',
    'Key_read_requests',
    'Created_tmp_tables',
    'Created_tmp_disk_tables',
    'Table_locks_waited',
    'Table_locks_immediate'
)
ORDER BY VARIABLE_NAME;

-- ============================================================================
-- MAINTENANCE COMMANDS
-- ============================================================================

-- Generate OPTIMIZE TABLE commands for fragmented tables
SELECT 
    CONCAT('OPTIMIZE TABLE ', table_schema, '.', table_name, ';') as optimize_command
FROM information_schema.tables 
WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND data_free > 0
    AND (data_free / (data_length + index_length)) > 0.1
    AND engine = 'InnoDB'
ORDER BY (data_free / (data_length + index_length)) DESC;

-- Generate ANALYZE TABLE commands
SELECT 
    CONCAT('ANALYZE TABLE ', table_schema, '.', table_name, ';') as analyze_command
FROM information_schema.tables 
WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND engine = 'InnoDB'
ORDER BY table_name;

-- ============================================================================
-- SECURITY MONITORING
-- ============================================================================

-- List all users and their privileges
SELECT 
    User,
    Host,
    Select_priv,
    Insert_priv,
    Update_priv,
    Delete_priv,
    Create_priv,
    Drop_priv,
    Reload_priv,
    Shutdown_priv,
    Process_priv,
    File_priv,
    Grant_priv,
    References_priv,
    Index_priv,
    Alter_priv,
    Show_db_priv,
    Super_priv,
    Create_tmp_table_priv,
    Lock_tables_priv,
    Execute_priv,
    Repl_slave_priv,
    Repl_client_priv,
    Create_view_priv,
    Show_view_priv,
    Create_routine_priv,
    Alter_routine_priv,
    Create_user_priv,
    Event_priv,
    Trigger_priv,
    Create_tablespace_priv,
    ssl_type,
    ssl_cipher,
    x509_issuer,
    x509_subject,
    max_questions,
    max_updates,
    max_connections,
    max_user_connections,
    plugin,
    authentication_string,
    password_expired,
    password_last_changed,
    password_lifetime,
    account_locked
FROM mysql.user
ORDER BY User, Host;

-- Database-specific privileges
SELECT 
    User,
    Host,
    Db,
    Select_priv,
    Insert_priv,
    Update_priv,
    Delete_priv,
    Create_priv,
    Drop_priv,
    Grant_priv,
    References_priv,
    Index_priv,
    Alter_priv,
    Create_tmp_table_priv,
    Lock_tables_priv,
    Create_view_priv,
    Show_view_priv,
    Create_routine_priv,
    Alter_routine_priv,
    Execute_priv,
    Event_priv,
    Trigger_priv
FROM mysql.db
ORDER BY Db, User, Host;