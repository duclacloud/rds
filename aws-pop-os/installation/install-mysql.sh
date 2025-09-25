#!/bin/bash

# MySQL Installation Script for Pop!_OS 22.04
# Usage: ./install-mysql.sh

set -e

echo "🐬 Installing MySQL on Pop!_OS 22.04..."

# Update system
echo "📦 Updating system packages..."
sudo apt update

# Install MySQL Server
echo "🔧 Installing MySQL Server..."
sudo apt install -y mysql-server mysql-client

# Start and enable service
echo "🚀 Starting MySQL service..."
sudo systemctl start mysql
sudo systemctl enable mysql

# Secure installation
echo "🔐 Running MySQL secure installation..."
sudo mysql_secure_installation

# Create development user
echo "👤 Creating development user..."
read -p "Enter username for development: " DEV_USER
read -s -p "Enter password for $DEV_USER: " DEV_PASSWORD
echo
read -s -p "Enter MySQL root password: " ROOT_PASSWORD
echo

# Create user and database
mysql -u root -p$ROOT_PASSWORD << EOF
CREATE USER '$DEV_USER'@'localhost' IDENTIFIED BY '$DEV_PASSWORD';
CREATE DATABASE ${DEV_USER}_dev CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON ${DEV_USER}_dev.* TO '$DEV_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Configure MySQL
echo "⚙️ Configuring MySQL..."
MYSQL_CONFIG="/etc/mysql/mysql.conf.d/mysqld.cnf"

# Backup original config
sudo cp $MYSQL_CONFIG $MYSQL_CONFIG.backup

# Update configuration
sudo sed -i "s/bind-address.*/bind-address = 127.0.0.1/" $MYSQL_CONFIG

# Restart MySQL
echo "🔄 Restarting MySQL..."
sudo systemctl restart mysql

# Test connection
echo "🧪 Testing connection..."
if mysql -h localhost -u $DEV_USER -p$DEV_PASSWORD -e "SELECT VERSION();" > /dev/null 2>&1; then
    echo "✅ MySQL installation completed successfully!"
    echo "📋 Connection details:"
    echo "   Host: localhost"
    echo "   Port: 3306"
    echo "   User: $DEV_USER"
    echo "   Database: ${DEV_USER}_dev"
    echo "   Admin User: root"
else
    echo "❌ Connection test failed. Please check the installation."
    exit 1
fi

echo "🎉 MySQL is ready for development!"