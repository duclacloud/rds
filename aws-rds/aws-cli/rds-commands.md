# AWS CLI - RDS Management Commands

## 🔍 **Database Instance Management**

### **List Instances**
```bash
# List all RDS instances
aws rds describe-db-instances

# List specific instance
aws rds describe-db-instances --db-instance-identifier mydb-instance

# List with specific output
aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Engine]' --output table
```

### **Create Instance**
```bash
# Create PostgreSQL instance
aws rds create-db-instance \
    --db-instance-identifier mypostgres-db \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --master-username admin \
    --master-user-password MySecurePassword123 \
    --allocated-storage 20 \
    --vpc-security-group-ids sg-12345678 \
    --db-subnet-group-name my-subnet-group

# Create MySQL instance
aws rds create-db-instance \
    --db-instance-identifier mysql-db \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --master-username admin \
    --master-user-password MySecurePassword123 \
    --allocated-storage 20 \
    --vpc-security-group-ids sg-12345678
```

### **Modify Instance**
```bash
# Change instance class
aws rds modify-db-instance \
    --db-instance-identifier mydb-instance \
    --db-instance-class db.t3.small \
    --apply-immediately

# Enable backup
aws rds modify-db-instance \
    --db-instance-identifier mydb-instance \
    --backup-retention-period 7 \
    --apply-immediately
```

### **Start/Stop Instance**
```bash
# Stop instance
aws rds stop-db-instance --db-instance-identifier mydb-instance

# Start instance
aws rds start-db-instance --db-instance-identifier mydb-instance

# Reboot instance
aws rds reboot-db-instance --db-instance-identifier mydb-instance
```

### **Delete Instance**
```bash
# Delete with final snapshot
aws rds delete-db-instance \
    --db-instance-identifier mydb-instance \
    --final-db-snapshot-identifier mydb-final-snapshot

# Delete without snapshot (careful!)
aws rds delete-db-instance \
    --db-instance-identifier mydb-instance \
    --skip-final-snapshot
```

## 📊 **Monitoring & Performance**

### **CloudWatch Metrics**
```bash
# Get CPU utilization
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name CPUUtilization \
    --dimensions Name=DBInstanceIdentifier,Value=mydb-instance \
    --start-time 2024-01-01T00:00:00Z \
    --end-time 2024-01-02T00:00:00Z \
    --period 3600 \
    --statistics Average

# Get database connections
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name DatabaseConnections \
    --dimensions Name=DBInstanceIdentifier,Value=mydb-instance \
    --start-time 2024-01-01T00:00:00Z \
    --end-time 2024-01-02T00:00:00Z \
    --period 3600 \
    --statistics Average
```

### **Performance Insights**
```bash
# Enable Performance Insights
aws rds modify-db-instance \
    --db-instance-identifier mydb-instance \
    --enable-performance-insights \
    --performance-insights-retention-period 7

# Get performance data
aws pi get-resource-metrics \
    --service-type RDS \
    --identifier db-ABCDEFGHIJKLMNOP \
    --start-time 2024-01-01T00:00:00Z \
    --end-time 2024-01-01T01:00:00Z \
    --period-in-seconds 60 \
    --metric-queries MetricQuery='Metric=db.SQL.Innodb_rows_read.avg,GroupBy={Group=db.sql_tokenized.statement}'
```

## 💾 **Backup & Snapshots**

### **Manual Snapshots**
```bash
# Create snapshot
aws rds create-db-snapshot \
    --db-instance-identifier mydb-instance \
    --db-snapshot-identifier mydb-snapshot-$(date +%Y%m%d)

# List snapshots
aws rds describe-db-snapshots --db-instance-identifier mydb-instance

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier restored-db \
    --db-snapshot-identifier mydb-snapshot-20240101
```

### **Automated Backups**
```bash
# Configure backup window
aws rds modify-db-instance \
    --db-instance-identifier mydb-instance \
    --backup-retention-period 7 \
    --preferred-backup-window "03:00-04:00" \
    --apply-immediately

# Restore to point in time
aws rds restore-db-instance-to-point-in-time \
    --source-db-instance-identifier mydb-instance \
    --target-db-instance-identifier restored-db \
    --restore-time 2024-01-01T12:00:00Z
```

## 🔐 **Security Management**

### **Security Groups**
```bash
# Create security group
aws ec2 create-security-group \
    --group-name rds-security-group \
    --description "RDS Security Group"

# Add inbound rule for PostgreSQL
aws ec2 authorize-security-group-ingress \
    --group-id sg-12345678 \
    --protocol tcp \
    --port 5432 \
    --source-group sg-87654321

# Add inbound rule for MySQL
aws ec2 authorize-security-group-ingress \
    --group-id sg-12345678 \
    --protocol tcp \
    --port 3306 \
    --source-group sg-87654321
```

### **Parameter Groups**
```bash
# Create parameter group
aws rds create-db-parameter-group \
    --db-parameter-group-name my-postgres-params \
    --db-parameter-group-family postgres14 \
    --description "Custom PostgreSQL parameters"

# Modify parameters
aws rds modify-db-parameter-group \
    --db-parameter-group-name my-postgres-params \
    --parameters "ParameterName=shared_preload_libraries,ParameterValue=pg_stat_statements,ApplyMethod=pending-reboot"

# Apply parameter group
aws rds modify-db-instance \
    --db-instance-identifier mydb-instance \
    --db-parameter-group-name my-postgres-params
```

## 📈 **Cost Optimization**

### **Reserved Instances**
```bash
# List available reserved instances
aws rds describe-reserved-db-instances-offerings \
    --db-instance-class db.t3.micro \
    --engine postgres

# Purchase reserved instance
aws rds purchase-reserved-db-instances-offering \
    --reserved-db-instances-offering-id 12345678-1234-1234-1234-123456789012
```

### **Cost Monitoring**
```bash
# Get cost and usage (requires Cost Explorer API)
aws ce get-cost-and-usage \
    --time-period Start=2024-01-01,End=2024-01-31 \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --group-by Type=DIMENSION,Key=SERVICE
```