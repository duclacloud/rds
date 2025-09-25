# RDS Workshop - Database Mẫu & Testing

## 🎯 **Mục Tiêu Workshop**
Tạo database mẫu với dữ liệu giả định và test các thông số performance, monitoring.

## 🗄️ **1. Tạo Database Mẫu**

### **PostgreSQL Setup**
```sql
-- Kết nối và tạo database
CREATE DATABASE ecommerce_demo 
    WITH ENCODING = 'UTF8' 
    LC_COLLATE = 'en_US.UTF-8' 
    LC_CTYPE = 'en_US.UTF-8';

\c ecommerce_demo;

-- Tạo extension cần thiết
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Tạo bảng users
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true
);

-- Tạo bảng categories
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tạo bảng products
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INTEGER DEFAULT 0,
    category_id INTEGER REFERENCES categories(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tạo bảng orders
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    total_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tạo bảng order_items
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id),
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL
);

-- Tạo indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created ON orders(created_at);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
```

### **MySQL Setup**
```sql
-- Tạo database
CREATE DATABASE ecommerce_demo 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

USE ecommerce_demo;

-- Tạo bảng users
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    INDEX idx_email (email),
    INDEX idx_username (username)
);

-- Tạo bảng categories
CREATE TABLE categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tạo bảng products
CREATE TABLE products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INT DEFAULT 0,
    category_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id),
    INDEX idx_category (category_id),
    INDEX idx_price (price)
);

-- Tạo bảng orders
CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    total_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_user (user_id),
    INDEX idx_status (status),
    INDEX idx_created (created_at)
);

-- Tạo bảng order_items
CREATE TABLE order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id),
    INDEX idx_order (order_id),
    INDEX idx_product (product_id)
);
```

## 📊 **2. Thêm Dữ Liệu Giả Định**

### **PostgreSQL Data**
```sql
-- Thêm categories
INSERT INTO categories (name, description) VALUES
('Electronics', 'Electronic devices and gadgets'),
('Clothing', 'Fashion and apparel'),
('Books', 'Books and literature'),
('Home & Garden', 'Home improvement and gardening'),
('Sports', 'Sports equipment and accessories');

-- Thêm users (1000 users)
INSERT INTO users (username, email, password_hash, first_name, last_name)
SELECT 
    'user' || generate_series,
    'user' || generate_series || '@example.com',
    crypt('password123', gen_salt('bf')),
    'FirstName' || generate_series,
    'LastName' || generate_series
FROM generate_series(1, 1000);

-- Thêm products (5000 products)
INSERT INTO products (name, description, price, stock_quantity, category_id)
SELECT 
    'Product ' || generate_series,
    'Description for product ' || generate_series,
    (random() * 1000 + 10)::decimal(10,2),
    (random() * 100 + 1)::integer,
    (random() * 4 + 1)::integer
FROM generate_series(1, 5000);

-- Thêm orders (10000 orders)
INSERT INTO orders (user_id, total_amount, status)
SELECT 
    (random() * 999 + 1)::integer,
    (random() * 500 + 20)::decimal(10,2),
    CASE 
        WHEN random() < 0.7 THEN 'completed'
        WHEN random() < 0.9 THEN 'pending'
        ELSE 'cancelled'
    END
FROM generate_series(1, 10000);

-- Thêm order_items (30000 items)
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
SELECT 
    (random() * 9999 + 1)::integer,
    (random() * 4999 + 1)::integer,
    (random() * 5 + 1)::integer,
    (random() * 100 + 5)::decimal(10,2),
    ((random() * 5 + 1) * (random() * 100 + 5))::decimal(10,2)
FROM generate_series(1, 30000);
```

### **MySQL Data**
```sql
-- Thêm categories
INSERT INTO categories (name, description) VALUES
('Electronics', 'Electronic devices and gadgets'),
('Clothing', 'Fashion and apparel'),
('Books', 'Books and literature'),
('Home & Garden', 'Home improvement and gardening'),
('Sports', 'Sports equipment and accessories');

-- Tạo procedure để thêm users
DELIMITER //
CREATE PROCEDURE AddUsers()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 1000 DO
        INSERT INTO users (username, email, password_hash, first_name, last_name)
        VALUES (
            CONCAT('user', i),
            CONCAT('user', i, '@example.com'),
            SHA2(CONCAT('password123', i), 256),
            CONCAT('FirstName', i),
            CONCAT('LastName', i)
        );
        SET i = i + 1;
    END WHILE;
END //
DELIMITER ;

CALL AddUsers();

-- Tạo procedure để thêm products
DELIMITER //
CREATE PROCEDURE AddProducts()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 5000 DO
        INSERT INTO products (name, description, price, stock_quantity, category_id)
        VALUES (
            CONCAT('Product ', i),
            CONCAT('Description for product ', i),
            ROUND(RAND() * 1000 + 10, 2),
            FLOOR(RAND() * 100 + 1),
            FLOOR(RAND() * 5 + 1)
        );
        SET i = i + 1;
    END WHILE;
END //
DELIMITER ;

CALL AddProducts();

-- Tạo procedure để thêm orders
DELIMITER //
CREATE PROCEDURE AddOrders()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE rand_status VARCHAR(20);
    WHILE i <= 10000 DO
        SET rand_status = CASE 
            WHEN RAND() < 0.7 THEN 'completed'
            WHEN RAND() < 0.9 THEN 'pending'
            ELSE 'cancelled'
        END;
        
        INSERT INTO orders (user_id, total_amount, status)
        VALUES (
            FLOOR(RAND() * 1000 + 1),
            ROUND(RAND() * 500 + 20, 2),
            rand_status
        );
        SET i = i + 1;
    END WHILE;
END //
DELIMITER ;

CALL AddOrders();
```

## 🧪 **3. Test Performance Queries**

### **Basic Performance Tests**
```sql
-- Test 1: Simple SELECT với WHERE
SELECT * FROM users WHERE email = 'user500@example.com';

-- Test 2: JOIN query
SELECT 
    u.username,
    COUNT(o.id) as order_count,
    SUM(o.total_amount) as total_spent
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.is_active = true
GROUP BY u.id, u.username
ORDER BY total_spent DESC
LIMIT 10;

-- Test 3: Complex aggregation
SELECT 
    c.name as category,
    COUNT(p.id) as product_count,
    AVG(p.price) as avg_price,
    SUM(oi.quantity) as total_sold
FROM categories c
JOIN products p ON c.id = p.category_id
JOIN order_items oi ON p.id = oi.product_id
JOIN orders o ON oi.order_id = o.id
WHERE o.status = 'completed'
GROUP BY c.id, c.name
ORDER BY total_sold DESC;

-- Test 4: Subquery performance
SELECT 
    p.name,
    p.price,
    (SELECT COUNT(*) FROM order_items oi WHERE oi.product_id = p.id) as times_ordered
FROM products p
WHERE p.price > (SELECT AVG(price) FROM products)
ORDER BY times_ordered DESC
LIMIT 20;
```

## 📈 **4. Monitoring & Analysis**

### **PostgreSQL Monitoring**
```sql
-- Kiểm tra query performance
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    stddev_exec_time
FROM pg_stat_statements 
ORDER BY total_exec_time DESC 
LIMIT 10;

-- Kiểm tra table statistics
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

-- Kiểm tra index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_tup_read,
    idx_tup_fetch,
    idx_scan
FROM pg_stat_user_indexes
ORDER BY idx_tup_read DESC;

-- Kiểm tra buffer hit ratio
SELECT 
    round(
        100.0 * sum(blks_hit) / (sum(blks_hit) + sum(blks_read)), 2
    ) as buffer_hit_ratio
FROM pg_stat_database;
```

### **MySQL Monitoring**
```sql
-- Kiểm tra slow queries
SELECT 
    DIGEST_TEXT,
    COUNT_STAR as executions,
    AVG_TIMER_WAIT/1000000000 as avg_time_sec,
    SUM_TIMER_WAIT/1000000000 as total_time_sec
FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;

-- Kiểm tra table I/O
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
WHERE OBJECT_SCHEMA = 'ecommerce_demo'
ORDER BY COUNT_READ + COUNT_WRITE DESC;

-- Kiểm tra index usage
SELECT 
    TABLE_SCHEMA,
    TABLE_NAME,
    INDEX_NAME,
    CARDINALITY
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA = 'ecommerce_demo'
ORDER BY CARDINALITY DESC;
```

## 🔧 **5. Performance Tuning Tests**

### **Test Index Effectiveness**
```sql
-- Test query without index
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM products WHERE description LIKE '%product 1000%';

-- Create index and test again
CREATE INDEX idx_products_description ON products USING gin(to_tsvector('english', description));

-- Test with index
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM products WHERE to_tsvector('english', description) @@ to_tsquery('product & 1000');
```

### **Test Query Optimization**
```sql
-- Slow query (Cartesian product)
EXPLAIN ANALYZE
SELECT COUNT(*) 
FROM users u, orders o, products p
WHERE u.id < 100 AND o.total_amount > 100 AND p.price > 50;

-- Optimized query
EXPLAIN ANALYZE
SELECT COUNT(*)
FROM users u
JOIN orders o ON u.id = o.user_id
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id
WHERE u.id < 100 AND o.total_amount > 100 AND p.price > 50;
```

## 📊 **6. Load Testing Scenarios**

### **Concurrent Connection Test**
```sql
-- Tạo function để simulate load
CREATE OR REPLACE FUNCTION simulate_user_activity()
RETURNS void AS $$
DECLARE
    user_id INTEGER;
    product_id INTEGER;
    order_id INTEGER;
BEGIN
    -- Random user
    SELECT id INTO user_id FROM users ORDER BY random() LIMIT 1;
    
    -- Create order
    INSERT INTO orders (user_id, total_amount, status)
    VALUES (user_id, random() * 200 + 50, 'pending')
    RETURNING id INTO order_id;
    
    -- Add random items
    FOR i IN 1..floor(random() * 5 + 1) LOOP
        SELECT id INTO product_id FROM products ORDER BY random() LIMIT 1;
        INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
        SELECT order_id, product_id, floor(random() * 3 + 1), price, price * floor(random() * 3 + 1)
        FROM products WHERE id = product_id;
    END LOOP;
    
    -- Update order total
    UPDATE orders 
    SET total_amount = (SELECT SUM(total_price) FROM order_items WHERE order_id = orders.id)
    WHERE id = order_id;
END;
$$ LANGUAGE plpgsql;

-- Run load test
SELECT simulate_user_activity() FROM generate_series(1, 100);
```

## 📋 **7. Workshop Checklist**

### **Setup Tasks**
- [ ] Tạo database và tables
- [ ] Thêm indexes cơ bản
- [ ] Insert dữ liệu mẫu
- [ ] Enable monitoring extensions

### **Performance Tests**
- [ ] Test basic queries
- [ ] Test complex JOINs
- [ ] Test aggregation queries
- [ ] Analyze query plans

### **Monitoring Tasks**
- [ ] Check query statistics
- [ ] Monitor index usage
- [ ] Check buffer hit ratios
- [ ] Review slow queries

### **Optimization Tasks**
- [ ] Identify slow queries
- [ ] Add missing indexes
- [ ] Optimize query structure
- [ ] Test performance improvements

## 🎯 **Expected Results**

### **Performance Benchmarks**
- Simple SELECT: < 1ms
- JOIN queries: < 10ms
- Complex aggregations: < 100ms
- Buffer hit ratio: > 99%
- Index usage: > 95% for indexed columns

### **Monitoring Metrics**
- Active connections: Monitor during load tests
- CPU utilization: Should stay < 80%
- Memory usage: Monitor buffer pool efficiency
- I/O operations: Track read/write patterns