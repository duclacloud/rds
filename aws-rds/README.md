# RDS Management Guide

## 📁 **Cấu Trúc Thư Mục**

```
rds/
├── aws-cli/                    # AWS CLI commands
│   ├── rds-commands.md        # RDS management commands
│   └── monitoring-commands.md  # Monitoring & backup commands
├── postgres/                   # PostgreSQL administration
│   ├── admin-commands.md      # Admin commands
│   └── maintenance-queries.sql # Maintenance queries
├── mysql/                      # MySQL administration
│   ├── admin-commands.md      # Admin commands
│   └── maintenance-queries.sql # Maintenance queries
├── scripts/                    # Automation scripts
│   ├── backup-script.sh       # Backup automation
│   └── monitoring-script.sh   # Monitoring automation
└── README.md                   # This file
```

## 🚀 **Quick Start**

### **1. AWS CLI Setup**
```bash
# Configure AWS CLI
aws configure

# Test connection
aws rds describe-db-instances
```

### **2. Database Connections**
```bash
# PostgreSQL
psql -h your-postgres-endpoint -U username -d database

# MySQL
mysql -h your-mysql-endpoint -u username -p database
```

## 📚 **Documentation**

- **[AWS CLI Commands](./aws-cli/rds-commands.md)** - RDS management via AWS CLI
- **[PostgreSQL Admin](./postgres/admin-commands.md)** - PostgreSQL administration
- **[MySQL Admin](./mysql/admin-commands.md)** - MySQL administration
- **[Common Tasks](./common-tasks.md)** - Daily, weekly & monthly operations guide
- **[Workshop](./workshop.md)** - Hands-on database setup & testing
- **[Database Architecture](../database-architecture.md)** - PostgreSQL & MySQL architecture
- **[Oracle Architecture](../oracle-architecture.md)** - Oracle Database architecture
- **[Automation Scripts](./scripts/)** - Backup & monitoring scripts

## 🔧 **Common Tasks**

### **Daily Operations**
- [Monitor database performance](./common-tasks.md#1-monitor-database-performance)
- [Check backup status](./common-tasks.md#2-check-backup-status)
- [Review slow queries](./common-tasks.md#3-review-slow-queries)
- [Monitor disk space](./common-tasks.md#4-monitor-disk-space)

### **Weekly Operations**
- [Update statistics](./common-tasks.md#1-update-statistics)
- [Review security logs](./common-tasks.md#2-review-security-logs)
- [Performance tuning](./common-tasks.md#3-performance-tuning)
- [Backup verification](./common-tasks.md#4-backup-verification)

### **Monthly Operations**
- [Security patches](./common-tasks.md#1-security-patches)
- [Capacity planning](./common-tasks.md#2-capacity-planning)
- [Cost optimization](./common-tasks.md#3-cost-optimization)
- [Documentation updates](./common-tasks.md#4-documentation-updates)

**📋 [Xem hướng dẫn chi tiết →](./common-tasks.md)**