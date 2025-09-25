# Local Database Development - Pop!_OS 22.04

## 🎯 **Mục Đích**
Setup PostgreSQL và MySQL trên Pop!_OS để development và testing local, sử dụng lại toàn bộ commands và scripts từ AWS RDS.

## 📁 **Cấu Trúc Đơn Giản**

```
aws-pop-os/
├── installation/           # Scripts cài đặt local
│   ├── install-postgresql.sh
│   └── install-mysql.sh
└── README.md              # This file
```

**Tái sử dụng từ aws-rds/:**
- **PostgreSQL Commands** → `../aws-rds/postgres/admin-commands.md`
- **MySQL Commands** → `../aws-rds/mysql/admin-commands.md`  
- **Workshop** → `../aws-rds/workshop.md`
- **Common Tasks** → `../aws-rds/common-tasks.md`
- **Scripts** → `../aws-rds/scripts/`

## 🚀 **Quick Start**

### **1. Cài Đặt Databases**
```bash
# PostgreSQL
./installation/install-postgresql.sh

# MySQL  
./installation/install-mysql.sh
```

### **2. Sử Dụng AWS RDS Guides**
```bash
# PostgreSQL admin (thay endpoint bằng localhost)
psql -h localhost -U your_user -d your_db

# MySQL admin (thay endpoint bằng localhost)
mysql -h localhost -u your_user -p your_db

# Chạy workshop từ aws-rds
psql -h localhost -U your_user -f ../aws-rds/workshop.md
```

### **3. Monitoring Local**
```bash
# Sử dụng monitoring commands từ aws-rds
# Thay AWS CLI bằng direct DB connections
```

## 🔄 **Tái Sử Dụng AWS RDS**

### **PostgreSQL**
- Sử dụng tất cả SQL commands từ `../aws-rds/postgres/admin-commands.md`
- Thay `your-rds-endpoint.amazonaws.com` → `localhost`
- Thay AWS CLI monitoring → Direct SQL queries

### **MySQL**
- Sử dụng tất cả SQL commands từ `../aws-rds/mysql/admin-commands.md`
- Thay `your-rds-endpoint.amazonaws.com` → `localhost`
- Thay AWS CLI monitoring → Direct SQL queries

### **Workshop & Testing**
- Chạy `../aws-rds/workshop.md` trực tiếp trên local
- Sử dụng `../aws-rds/common-tasks.md` (bỏ qua AWS CLI parts)

## 🔗 **Sử Dụng AWS RDS Guides**
- **[PostgreSQL Admin](../aws-rds/postgres/admin-commands.md)** - Tất cả PostgreSQL commands
- **[MySQL Admin](../aws-rds/mysql/admin-commands.md)** - Tất cả MySQL commands
- **[Workshop](../aws-rds/workshop.md)** - Database workshop (chạy trực tiếp)
- **[Common Tasks](../aws-rds/common-tasks.md)** - Daily operations (SQL parts)
- **[Database Architecture](../database-architecture.md)** - Kiến trúc PostgreSQL & MySQL
- **[Oracle Architecture](../oracle-architecture.md)** - Kiến trúc Oracle Database
- **[AWS RDS Guide](../aws-rds/README.md)** - Production deployment

## 📋 **Development Workflow**

1. **Install Local** → Chỉ cần cài PostgreSQL/MySQL
2. **Use RDS Guides** → Tái sử dụng 100% SQL commands
3. **Test Local** → Same queries, localhost connection
4. **Deploy AWS** → Same commands, RDS endpoint