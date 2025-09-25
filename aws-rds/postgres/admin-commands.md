# PostgreSQL Administration Commands

## 🔗 **Connection & Authentication**

### **Connect to Database**
```bash
# Connect via psql
psql -h your-rds-endpoint.amazonaws.com -U username -d database_name

# Connect with SSL
psql "host=your-rds-endpoint.amazonaws.com port=5432 dbname=database_name user=username sslmode=require"

# Connect and run single command
psql -h your-rds-endpoint.amazonaws.com -U username -d database_name -c "SELECT version();"
```

## 👥 **User Management**

### **Create Users**
```sql
-- Create user with password
CREATE USER app_user WITH PASSWORD 'secure_password';

-- Create user with specific privileges
CREATE USER readonly_user WITH PASSWORD 'password' 
    NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- Create application user
CREATE USER app_service WITH PASSWORD 'app_password'
    CREATEDB NOCREATEROLE;
```

### **Grant Permissions**
```sql
-- Grant database access
GRANT CONNECT ON DATABASE myapp TO app_user;

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO app_user;

-- Grant table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;

-- Grant sequence permissions
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- Grant future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
```

### **Revoke Permissions**
```sql
-- Revoke specific permissions
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM readonly_user;

-- Remove user
DROP USER IF EXISTS old_user;
```

## 🗄️ **Database Management**

### **Create Database**
```sql
-- Create database
CREATE DATABASE myapp 
    WITH OWNER = app_user
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8';

-- Create database with template
CREATE DATABASE test_db WITH TEMPLATE myapp;
```

### **Database Information**
```sql
-- List databases
\l
SELECT datname FROM pg_database;

-- Database size
SELECT 
    datname,
    pg_size_pretty(pg_database_size(datname)) as size
FROM pg_database 
ORDER BY pg_database_size(datname) DESC;

-- Current database info
SELECT current_database(), current_user, version();
```

## 📊 **Monitoring & Performance**

### **Active Connections**
```sql
-- Current connections
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query_start,
    query
FROM pg_stat_activity 
WHERE state = 'active';

-- Connection count by database
SELECT 
    datname,
    count(*) as connections
FROM pg_stat_activity 
GROUP BY datname;
```

### **Long Running Queries**
```sql
-- Queries running longer than 5 minutes
SELECT 
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query,
    state
FROM pg_stat_activity 
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes'
    AND state = 'active';

-- Kill long running query
SELECT pg_terminate_backend(pid) FROM pg_stat_activity 
WHERE pid = 12345;
```

### **Database Statistics**
```sql
-- Table statistics
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;

-- Index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_tup_read DESC;
```

## 🔧 **Maintenance Operations**

### **VACUUM & ANALYZE**
```sql
-- Manual vacuum
VACUUM VERBOSE table_name;

-- Full vacuum (locks table)
VACUUM FULL table_name;

-- Analyze statistics
ANALYZE table_name;

-- Vacuum and analyze
VACUUM ANALYZE table_name;

-- Check last vacuum/analyze
SELECT 
    schemaname,
    tablename,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables;
```

### **Reindex Operations**
```sql
-- Reindex table
REINDEX TABLE table_name;

-- Reindex index
REINDEX INDEX index_name;

-- Reindex database (careful!)
REINDEX DATABASE database_name;
```

## 💾 **Backup & Restore**

### **Logical Backup**
```bash
# Dump single database
pg_dump -h endpoint -U username -d database_name > backup.sql

# Dump with compression
pg_dump -h endpoint -U username -d database_name | gzip > backup.sql.gz

# Dump specific tables
pg_dump -h endpoint -U username -d database_name -t table1 -t table2 > tables_backup.sql

# Dump schema only
pg_dump -h endpoint -U username -d database_name --schema-only > schema.sql
```

### **Restore**
```bash
# Restore database
psql -h endpoint -U username -d database_name < backup.sql

# Restore compressed backup
gunzip -c backup.sql.gz | psql -h endpoint -U username -d database_name

# Restore with verbose output
psql -h endpoint -U username -d database_name -v ON_ERROR_STOP=1 < backup.sql
```

## 🔍 **Query Optimization**

### **Explain Plans**
```sql
-- Basic explain
EXPLAIN SELECT * FROM users WHERE email = 'user@example.com';

-- Detailed explain
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) 
SELECT * FROM users u 
JOIN orders o ON u.id = o.user_id 
WHERE u.created_at > '2024-01-01';

-- Explain format
EXPLAIN (FORMAT JSON) SELECT * FROM users;
```

### **Index Management**
```sql
-- Create index
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);

-- Unique index
CREATE UNIQUE INDEX CONCURRENTLY idx_users_username ON users(username);

-- Partial index
CREATE INDEX CONCURRENTLY idx_active_users ON users(email) 
WHERE active = true;

-- Drop index
DROP INDEX CONCURRENTLY idx_users_email;

-- List indexes
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'public';
```

## 📈 **Performance Tuning**

### **Configuration Check**
```sql
-- Current settings
SHOW all;

-- Specific setting
SHOW shared_buffers;
SHOW work_mem;
SHOW maintenance_work_mem;

-- Memory settings
SELECT 
    name,
    setting,
    unit,
    context
FROM pg_settings 
WHERE name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem');
```

### **Wait Events**
```sql
-- Current wait events
SELECT 
    pid,
    wait_event_type,
    wait_event,
    state,
    query
FROM pg_stat_activity 
WHERE wait_event IS NOT NULL;
```

## 🚨 **Troubleshooting**

### **Lock Information**
```sql
-- Current locks
SELECT 
    l.pid,
    l.mode,
    l.locktype,
    l.relation::regclass,
    a.query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE NOT l.granted;

-- Blocking queries
SELECT 
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS current_statement_in_blocking_process
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted AND blocking_locks.granted;
```

### **Error Logs**
```sql
-- Check log settings
SHOW log_destination;
SHOW log_statement;
SHOW log_min_duration_statement;

-- Enable query logging
ALTER SYSTEM SET log_statement = 'all';
SELECT pg_reload_conf();
```