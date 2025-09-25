# MySQL Administration Commands

## 🔗 **Connection & Authentication**

### **Connect to Database**
```bash
# Connect via mysql client
mysql -h your-rds-endpoint.amazonaws.com -u username -p database_name

# Connect with SSL
mysql -h your-rds-endpoint.amazonaws.com -u username -p --ssl-mode=REQUIRED

# Connect and run single command
mysql -h your-rds-endpoint.amazonaws.com -u username -p -e "SELECT VERSION();"

# Connect with specific port
mysql -h your-rds-endpoint.amazonaws.com -P 3306 -u username -p
```

## 👥 **User Management**

### **Create Users**
```sql
-- Create user with password
CREATE USER 'app_user'@'%' IDENTIFIED BY 'secure_password';

-- Create user with specific host
CREATE USER 'app_user'@'10.0.0.%' IDENTIFIED BY 'secure_password';

-- Create user with password validation
CREATE USER 'app_user'@'%' IDENTIFIED BY 'SecurePass123!' 
    PASSWORD EXPIRE INTERVAL 90 DAY;
```

### **Grant Permissions**
```sql
-- Grant database access
GRANT ALL PRIVILEGES ON myapp.* TO 'app_user'@'%';

-- Grant specific permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.* TO 'app_user'@'%';

-- Grant read-only access
GRANT SELECT ON myapp.* TO 'readonly_user'@'%';

-- Grant admin privileges (careful!)
GRANT ALL PRIVILEGES ON *.* TO 'admin_user'@'%' WITH GRANT OPTION;

-- Apply changes
FLUSH PRIVILEGES;
```

### **Revoke Permissions**
```sql
-- Revoke specific permissions
REVOKE INSERT, UPDATE, DELETE ON myapp.* FROM 'readonly_user'@'%';

-- Show user privileges
SHOW GRANTS FOR 'app_user'@'%';

-- Remove user
DROP USER 'old_user'@'%';
```

## 🗄️ **Database Management**

### **Create Database**
```sql
-- Create database
CREATE DATABASE myapp 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

-- Create database with specific settings
CREATE DATABASE myapp_test
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
```

### **Database Information**
```sql
-- List databases
SHOW DATABASES;

-- Database size
SELECT 
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables 
GROUP BY table_schema;

-- Current database info
SELECT DATABASE(), USER(), VERSION();

-- Table information
SELECT 
    table_name,
    table_rows,
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
FROM information_schema.tables 
WHERE table_schema = 'myapp'
ORDER BY (data_length + index_length) DESC;
```

## 📊 **Monitoring & Performance**

### **Active Connections**
```sql
-- Current connections
SHOW PROCESSLIST;

-- Detailed process information
SELECT 
    ID,
    USER,
    HOST,
    DB,
    COMMAND,
    TIME,
    STATE,
    INFO
FROM INFORMATION_SCHEMA.PROCESSLIST
WHERE COMMAND != 'Sleep';

-- Connection count by user
SELECT 
    USER,
    COUNT(*) as connections
FROM INFORMATION_SCHEMA.PROCESSLIST
GROUP BY USER;
```

### **Long Running Queries**
```sql
-- Queries running longer than 60 seconds
SELECT 
    ID,
    USER,
    HOST,
    DB,
    TIME,
    STATE,
    INFO
FROM INFORMATION_SCHEMA.PROCESSLIST
WHERE TIME > 60 AND COMMAND != 'Sleep';

-- Kill long running query
KILL 12345;

-- Kill connection
KILL CONNECTION 12345;
```

### **Performance Schema**
```sql
-- Enable Performance Schema (if not enabled)
-- Add to my.cnf: performance_schema = ON

-- Top queries by execution time
SELECT 
    DIGEST_TEXT,
    COUNT_STAR,
    AVG_TIMER_WAIT/1000000000 as avg_time_sec,
    SUM_TIMER_WAIT/1000000000 as total_time_sec
FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;

-- Table I/O statistics
SELECT 
    OBJECT_SCHEMA,
    OBJECT_NAME,
    COUNT_READ,
    COUNT_WRITE,
    COUNT_FETCH,
    COUNT_INSERT,
    COUNT_UPDATE,
    COUNT_DELETE
FROM performance_schema.table_io_waits_summary_by_table
WHERE OBJECT_SCHEMA NOT IN ('mysql', 'performance_schema', 'information_schema')
ORDER BY COUNT_READ + COUNT_WRITE DESC;
```

## 🔧 **Maintenance Operations**

### **Table Maintenance**
```sql
-- Analyze table
ANALYZE TABLE table_name;

-- Optimize table
OPTIMIZE TABLE table_name;

-- Check table
CHECK TABLE table_name;

-- Repair table
REPAIR TABLE table_name;

-- Show table status
SHOW TABLE STATUS FROM database_name;
```

### **Index Management**
```sql
-- Create index
CREATE INDEX idx_users_email ON users(email);

-- Unique index
CREATE UNIQUE INDEX idx_users_username ON users(username);

-- Composite index
CREATE INDEX idx_users_name_email ON users(first_name, last_name, email);

-- Drop index
DROP INDEX idx_users_email ON users;

-- Show indexes
SHOW INDEX FROM users;

-- Index usage statistics
SELECT 
    TABLE_SCHEMA,
    TABLE_NAME,
    INDEX_NAME,
    CARDINALITY
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA = 'myapp';
```

## 💾 **Backup & Restore**

### **Logical Backup**
```bash
# Dump single database
mysqldump -h endpoint -u username -p database_name > backup.sql

# Dump with compression
mysqldump -h endpoint -u username -p database_name | gzip > backup.sql.gz

# Dump specific tables
mysqldump -h endpoint -u username -p database_name table1 table2 > tables_backup.sql

# Dump structure only
mysqldump -h endpoint -u username -p --no-data database_name > structure.sql

# Dump data only
mysqldump -h endpoint -u username -p --no-create-info database_name > data.sql

# Dump with single transaction (InnoDB)
mysqldump -h endpoint -u username -p --single-transaction database_name > backup.sql
```

### **Restore**
```bash
# Restore database
mysql -h endpoint -u username -p database_name < backup.sql

# Restore compressed backup
gunzip -c backup.sql.gz | mysql -h endpoint -u username -p database_name

# Restore with verbose output
mysql -h endpoint -u username -p -v database_name < backup.sql
```

## 🔍 **Query Optimization**

### **Explain Plans**
```sql
-- Basic explain
EXPLAIN SELECT * FROM users WHERE email = 'user@example.com';

-- Detailed explain
EXPLAIN FORMAT=JSON 
SELECT * FROM users u 
JOIN orders o ON u.id = o.user_id 
WHERE u.created_at > '2024-01-01';

-- Explain with execution stats
EXPLAIN ANALYZE 
SELECT * FROM users WHERE email = 'user@example.com';
```

### **Slow Query Log**
```sql
-- Enable slow query log
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;
SET GLOBAL log_queries_not_using_indexes = 'ON';

-- Check slow query settings
SHOW VARIABLES LIKE 'slow_query%';
SHOW VARIABLES LIKE 'long_query_time';

-- Analyze slow queries (use mysqldumpslow tool)
-- mysqldumpslow -s t -t 10 /var/log/mysql/slow.log
```

## 📈 **Performance Tuning**

### **Configuration Check**
```sql
-- Show all variables
SHOW VARIABLES;

-- Key buffer settings
SHOW VARIABLES LIKE 'key_buffer_size';
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';

-- Connection settings
SHOW VARIABLES LIKE 'max_connections';
SHOW VARIABLES LIKE 'thread_cache_size';

-- Query cache (MySQL 5.7 and earlier)
SHOW VARIABLES LIKE 'query_cache%';
SHOW STATUS LIKE 'Qcache%';
```

### **InnoDB Status**
```sql
-- InnoDB status
SHOW ENGINE INNODB STATUS;

-- Buffer pool usage
SELECT 
    POOL_ID,
    POOL_SIZE,
    FREE_BUFFERS,
    DATABASE_PAGES,
    OLD_DATABASE_PAGES
FROM INFORMATION_SCHEMA.INNODB_BUFFER_POOL_STATS;
```

## 🚨 **Troubleshooting**

### **Lock Information**
```sql
-- Current locks (MySQL 5.7+)
SELECT 
    r.trx_id waiting_trx_id,
    r.trx_mysql_thread_id waiting_thread,
    r.trx_query waiting_query,
    b.trx_id blocking_trx_id,
    b.trx_mysql_thread_id blocking_thread,
    b.trx_query blocking_query
FROM information_schema.innodb_lock_waits w
INNER JOIN information_schema.innodb_trx b ON b.trx_id = w.blocking_trx_id
INNER JOIN information_schema.innodb_trx r ON r.trx_id = w.requesting_trx_id;

-- Deadlock information
SHOW ENGINE INNODB STATUS;
```

### **Error Logs**
```sql
-- Check error log location
SHOW VARIABLES LIKE 'log_error';

-- General log settings
SHOW VARIABLES LIKE 'general_log%';

-- Binary log settings
SHOW VARIABLES LIKE 'log_bin%';
SHOW BINARY LOGS;
```

### **Replication Status**
```sql
-- Master status
SHOW MASTER STATUS;

-- Slave status
SHOW SLAVE STATUS\G

-- Replication lag
SELECT 
    SECONDS_BEHIND_MASTER 
FROM INFORMATION_SCHEMA.REPLICA_HOST_STATUS;
```

## 🔐 **Security**

### **SSL Configuration**
```sql
-- Check SSL status
SHOW STATUS LIKE 'Ssl_cipher';
SHOW VARIABLES LIKE 'have_ssl';

-- Force SSL for user
ALTER USER 'app_user'@'%' REQUIRE SSL;
```

### **Audit & Logging**
```sql
-- Enable general log
SET GLOBAL general_log = 'ON';
SET GLOBAL general_log_file = '/var/log/mysql/general.log';

-- Check login attempts
SELECT 
    USER,
    HOST,
    CONNECTION_TYPE
FROM INFORMATION_SCHEMA.PROCESSLIST;
```