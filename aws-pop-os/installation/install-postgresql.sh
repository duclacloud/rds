#!/bin/bash

# PostgreSQL Installation Script for Pop!_OS 22.04
# Usage: ./install-postgresql.sh

set -e

echo "🐘 Installing PostgreSQL on Pop!_OS 22.04..."

# Update system
echo "📦 Updating system packages..."
sudo apt update

# Install PostgreSQL
echo "🔧 Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib postgresql-client

# Start and enable service
echo "🚀 Starting PostgreSQL service..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Setup postgres user password
echo "🔐 Setting up postgres user..."
read -s -p "Enter password for postgres user: " POSTGRES_PASSWORD
echo
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD';"

# Create development user
echo "👤 Creating development user..."
read -p "Enter username for development: " DEV_USER
read -s -p "Enter password for $DEV_USER: " DEV_PASSWORD
echo

sudo -u postgres createuser --interactive --pwprompt $DEV_USER << EOF
$DEV_PASSWORD
$DEV_PASSWORD
y
y
y
EOF

# Create development database
echo "🗄️ Creating development database..."
sudo -u postgres createdb -O $DEV_USER ${DEV_USER}_dev

# Configure PostgreSQL
echo "⚙️ Configuring PostgreSQL..."
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP '\d+\.\d+' | head -1)
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"

# Backup original configs
sudo cp $PG_CONFIG_DIR/postgresql.conf $PG_CONFIG_DIR/postgresql.conf.backup
sudo cp $PG_CONFIG_DIR/pg_hba.conf $PG_CONFIG_DIR/pg_hba.conf.backup

# Update postgresql.conf
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" $PG_CONFIG_DIR/postgresql.conf
sudo sed -i "s/#port = 5432/port = 5432/" $PG_CONFIG_DIR/postgresql.conf

# Update pg_hba.conf for local connections
echo "local   all             all                                     md5" | sudo tee -a $PG_CONFIG_DIR/pg_hba.conf

# Restart PostgreSQL
echo "🔄 Restarting PostgreSQL..."
sudo systemctl restart postgresql

# Test connection
echo "🧪 Testing connection..."
if psql -h localhost -U $DEV_USER -d ${DEV_USER}_dev -c "SELECT version();" > /dev/null 2>&1; then
    echo "✅ PostgreSQL installation completed successfully!"
    echo "📋 Connection details:"
    echo "   Host: localhost"
    echo "   Port: 5432"
    echo "   User: $DEV_USER"
    echo "   Database: ${DEV_USER}_dev"
    echo "   Admin User: postgres"
else
    echo "❌ Connection test failed. Please check the installation."
    exit 1
fi

echo "🎉 PostgreSQL is ready for development!"