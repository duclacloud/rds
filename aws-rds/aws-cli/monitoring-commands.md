# AWS CLI - Monitoring & Backup Commands

## 📊 **CloudWatch Monitoring**

### **Basic Metrics**
```bash
# CPU Utilization
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name CPUUtilization \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 300 \
    --statistics Average,Maximum

# Database Connections
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name DatabaseConnections \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 300 \
    --statistics Average,Maximum

# Free Storage Space
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name FreeStorageSpace \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance \
    --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 3600 \
    --statistics Average,Minimum
```

### **Performance Metrics**
```bash
# Read/Write IOPS
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name ReadIOPS \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 300 \
    --statistics Average,Maximum

aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name WriteIOPS \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 300 \
    --statistics Average,Maximum

# Read/Write Latency
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name ReadLatency \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 300 \
    --statistics Average,Maximum
```

## 🚨 **CloudWatch Alarms**

### **Create Alarms**
```bash
# High CPU Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "RDS-HighCPU-your-db-instance" \
    --alarm-description "RDS CPU utilization is too high" \
    --metric-name CPUUtilization \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --alarm-actions arn:aws:sns:region:account:topic-name \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance

# Low Free Storage Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "RDS-LowStorage-your-db-instance" \
    --alarm-description "RDS free storage space is low" \
    --metric-name FreeStorageSpace \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 2000000000 \
    --comparison-operator LessThanThreshold \
    --evaluation-periods 1 \
    --alarm-actions arn:aws:sns:region:account:topic-name \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance

# High Connection Count Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "RDS-HighConnections-your-db-instance" \
    --alarm-description "RDS connection count is too high" \
    --metric-name DatabaseConnections \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --alarm-actions arn:aws:sns:region:account:topic-name \
    --dimensions Name=DBInstanceIdentifier,Value=your-db-instance
```

### **List and Manage Alarms**
```bash
# List all RDS alarms
aws cloudwatch describe-alarms \
    --alarm-name-prefix "RDS-" \
    --query 'MetricAlarms[*].[AlarmName,StateValue,MetricName]' \
    --output table

# Delete alarm
aws cloudwatch delete-alarms --alarm-names "RDS-HighCPU-your-db-instance"
```

## 💾 **Backup Management**

### **Manual Snapshots**
```bash
# Create manual snapshot
aws rds create-db-snapshot \
    --db-instance-identifier your-db-instance \
    --db-snapshot-identifier your-db-instance-snapshot-$(date +%Y%m%d-%H%M)

# List snapshots
aws rds describe-db-snapshots \
    --db-instance-identifier your-db-instance \
    --snapshot-type manual \
    --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime,Status]' \
    --output table

# Copy snapshot to another region
aws rds copy-db-snapshot \
    --source-db-snapshot-identifier arn:aws:rds:source-region:account:snapshot:source-snapshot \
    --target-db-snapshot-identifier target-snapshot-name \
    --source-region source-region

# Delete old snapshots
aws rds delete-db-snapshot \
    --db-snapshot-identifier old-snapshot-name
```

### **Automated Backup Configuration**
```bash
# Enable automated backups
aws rds modify-db-instance \
    --db-instance-identifier your-db-instance \
    --backup-retention-period 7 \
    --preferred-backup-window "03:00-04:00" \
    --apply-immediately

# Check backup configuration
aws rds describe-db-instances \
    --db-instance-identifier your-db-instance \
    --query 'DBInstances[0].[BackupRetentionPeriod,PreferredBackupWindow,LatestRestorableTime]'
```

### **Point-in-Time Recovery**
```bash
# Get latest restorable time
aws rds describe-db-instances \
    --db-instance-identifier your-db-instance \
    --query 'DBInstances[0].LatestRestorableTime'

# Restore to specific point in time
aws rds restore-db-instance-to-point-in-time \
    --source-db-instance-identifier your-db-instance \
    --target-db-instance-identifier restored-db-$(date +%Y%m%d) \
    --restore-time 2024-01-15T10:30:00Z \
    --db-instance-class db.t3.micro
```

## 📈 **Performance Insights**

### **Enable Performance Insights**
```bash
# Enable Performance Insights
aws rds modify-db-instance \
    --db-instance-identifier your-db-instance \
    --enable-performance-insights \
    --performance-insights-retention-period 7 \
    --apply-immediately

# Check Performance Insights status
aws rds describe-db-instances \
    --db-instance-identifier your-db-instance \
    --query 'DBInstances[0].[PerformanceInsightsEnabled,PerformanceInsightsRetentionPeriod]'
```

### **Query Performance Data**
```bash
# Get resource metrics
aws pi get-resource-metrics \
    --service-type RDS \
    --identifier $(aws rds describe-db-instances --db-instance-identifier your-db-instance --query 'DBInstances[0].DbiResourceId' --output text) \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period-in-seconds 300 \
    --metric-queries 'Metric=db.CPU.Innodb_rows_read.avg'

# Get dimension keys
aws pi get-dimension-key-details \
    --service-type RDS \
    --identifier $(aws rds describe-db-instances --db-instance-identifier your-db-instance --query 'DBInstances[0].DbiResourceId' --output text) \
    --group db.sql_tokenized.statement \
    --group-identifier "SELECT * FROM users WHERE id = ?"
```

## 🔍 **Enhanced Monitoring**

### **Enable Enhanced Monitoring**
```bash
# Create IAM role for enhanced monitoring
aws iam create-role \
    --role-name rds-monitoring-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "",
                "Effect": "Allow",
                "Principal": {
                    "Service": "monitoring.rds.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }'

# Attach policy to role
aws iam attach-role-policy \
    --role-name rds-monitoring-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole

# Enable enhanced monitoring
aws rds modify-db-instance \
    --db-instance-identifier your-db-instance \
    --monitoring-interval 60 \
    --monitoring-role-arn arn:aws:iam::account:role/rds-monitoring-role \
    --apply-immediately
```

## 📊 **Custom Metrics Dashboard**

### **Create CloudWatch Dashboard**
```bash
# Create dashboard JSON
cat > dashboard.json << 'EOF'
{
    "widgets": [
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "your-db-instance" ],
                    [ ".", "DatabaseConnections", ".", "." ],
                    [ ".", "FreeStorageSpace", ".", "." ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "RDS Metrics"
            }
        }
    ]
}
EOF

# Create dashboard
aws cloudwatch put-dashboard \
    --dashboard-name "RDS-Monitoring" \
    --dashboard-body file://dashboard.json
```

## 🔔 **SNS Notifications**

### **Setup SNS Topic**
```bash
# Create SNS topic
aws sns create-topic --name rds-alerts

# Subscribe email to topic
aws sns subscribe \
    --topic-arn arn:aws:sns:region:account:rds-alerts \
    --protocol email \
    --notification-endpoint your-email@example.com

# Test notification
aws sns publish \
    --topic-arn arn:aws:sns:region:account:rds-alerts \
    --message "Test RDS alert notification"
```

## 📋 **Monitoring Scripts**

### **Daily Health Check Script**
```bash
#!/bin/bash
# daily-health-check.sh

DB_INSTANCE="your-db-instance"
REGION="us-east-1"

echo "=== RDS Daily Health Check - $(date) ==="

# Check instance status
echo "Instance Status:"
aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE \
    --region $REGION \
    --query 'DBInstances[0].[DBInstanceStatus,EngineVersion]' \
    --output table

# Check CPU utilization (last hour)
echo "CPU Utilization (last hour):"
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name CPUUtilization \
    --dimensions Name=DBInstanceIdentifier,Value=$DB_INSTANCE \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 3600 \
    --statistics Average,Maximum \
    --region $REGION \
    --query 'Datapoints[0].[Average,Maximum]' \
    --output text

# Check free storage
echo "Free Storage Space:"
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name FreeStorageSpace \
    --dimensions Name=DBInstanceIdentifier,Value=$DB_INSTANCE \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --period 3600 \
    --statistics Average \
    --region $REGION \
    --query 'Datapoints[0].Average' \
    --output text | awk '{print $1/1024/1024/1024 " GB"}'

echo "=== Health Check Complete ==="
```

### **Weekly Backup Report**
```bash
#!/bin/bash
# weekly-backup-report.sh

DB_INSTANCE="your-db-instance"
REGION="us-east-1"

echo "=== Weekly Backup Report - $(date) ==="

# List recent snapshots
echo "Recent Manual Snapshots:"
aws rds describe-db-snapshots \
    --db-instance-identifier $DB_INSTANCE \
    --snapshot-type manual \
    --region $REGION \
    --query 'DBSnapshots[0:5].[DBSnapshotIdentifier,SnapshotCreateTime,Status]' \
    --output table

# Check automated backup settings
echo "Automated Backup Configuration:"
aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE \
    --region $REGION \
    --query 'DBInstances[0].[BackupRetentionPeriod,PreferredBackupWindow,LatestRestorableTime]' \
    --output table

echo "=== Backup Report Complete ==="
```