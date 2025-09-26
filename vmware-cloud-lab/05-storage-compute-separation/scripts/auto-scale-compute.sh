#!/bin/bash
# auto-scale-compute.sh - Auto-scaling stateless compute instances

# Configuration
POSTGRES_COMPUTE_IMAGE="$HOME/Golden-Images/postgres-compute-golden-latest.vmdk"
ORACLE_COMPUTE_IMAGE="$HOME/Golden-Images/oracle-compute-golden-latest.vmdk"
MYSQL_COMPUTE_IMAGE="$HOME/Golden-Images/mysql-compute-golden-latest.vmdk"

# Auto-scaling PostgreSQL compute
scale_postgres_compute() {
  local action=$1
  local current_count=$(ls $HOME/Virtual Machines/PG-Compute-* 2>/dev/null | wc -l)
  
  case $action in
    "scale_up")
      local new_num=$((current_count + 1))
      local new_ip="192.168.200.$((20 + new_num))"
      
      echo "🔥 Scaling up PostgreSQL: Adding PG-Compute-$(printf "%02d" $new_num)..."
      
      mkdir -p "$HOME/Virtual Machines/PG-Compute-$(printf "%02d" $new_num)"
      cd "$HOME/Virtual Machines/PG-Compute-$(printf "%02d" $new_num)"
      
      cp "$POSTGRES_COMPUTE_IMAGE" "PG-Compute-$(printf "%02d" $new_num).vmdk"
      
      cat > "PG-Compute-$(printf "%02d" $new_num).vmx" << EOF
.encoding = "UTF-8"
guestOS = "ubuntu-64"
displayName = "PG-Compute-$(printf "%02d" $new_num)"
memsize = "8192"
numvcpus = "4"
scsi0:0.fileName = "PG-Compute-$(printf "%02d" $new_num).vmdk"
ethernet0.connectionType = "custom"
ethernet0.vnet = "vmnet2"
EOF

      cat > user-data << EOF
#cloud-config
runcmd:
  - hostnamectl set-hostname pg-compute-$(printf "%02d" $new_num)
  - sed -i 's/192.168.200.100/$new_ip/g' /etc/netplan/01-netcfg.yaml
  - netplan apply
  - mount -a
  - systemctl start postgresql
  - systemctl enable postgresql
EOF
      
      echo "instance-id: PG-Compute-$(printf "%02d" $new_num)" > meta-data
      genisoimage -output cloud-init.iso -volid cidata -joliet -rock user-data meta-data
      
      vmrun -T ws start "PG-Compute-$(printf "%02d" $new_num).vmx" nogui
      
      # Update load balancer
      ssh ubuntu@192.168.200.10 << EOF
echo "    server pg-compute-$(printf "%02d" $new_num) $new_ip:5432 check" | sudo tee -a /etc/haproxy/haproxy.cfg
sudo systemctl reload haproxy
EOF
      
      echo "✅ PostgreSQL scaled up: PG-Compute-$(printf "%02d" $new_num) added"
      ;;
      
    "scale_down")
      if [ $current_count -gt 2 ]; then
        local last_vm=$(ls $HOME/Virtual Machines/PG-Compute-* | tail -1 | basename)
        echo "📉 Scaling down PostgreSQL: Removing $last_vm..."
        
        vmrun -T ws stop "$HOME/Virtual Machines/$last_vm/$last_vm.vmx"
        
        ssh ubuntu@192.168.200.10 << EOF
sudo sed -i "/$last_vm/d" /etc/haproxy/haproxy.cfg
sudo systemctl reload haproxy
EOF
        
        echo "✅ PostgreSQL scaled down: $last_vm removed"
      else
        echo "⚠️ Minimum 2 PostgreSQL compute instances required"
      fi
      ;;
  esac
}

# Auto-scaling Oracle compute
scale_oracle_compute() {
  local action=$1
  local current_count=$(ls $HOME/Virtual Machines/Oracle-Compute-* 2>/dev/null | wc -l)
  
  case $action in
    "scale_up")
      local new_num=$((current_count + 1))
      local new_ip="192.168.300.$((20 + new_num))"
      
      echo "🔥 Scaling up Oracle: Adding Oracle-Compute-$(printf "%02d" $new_num)..."
      
      mkdir -p "$HOME/Virtual Machines/Oracle-Compute-$(printf "%02d" $new_num)"
      cd "$HOME/Virtual Machines/Oracle-Compute-$(printf "%02d" $new_num)"
      
      cp "$ORACLE_COMPUTE_IMAGE" "Oracle-Compute-$(printf "%02d" $new_num).vmdk"
      
      cat > "Oracle-Compute-$(printf "%02d" $new_num).vmx" << EOF
.encoding = "UTF-8"
guestOS = "rhel9-64"
displayName = "Oracle-Compute-$(printf "%02d" $new_num)"
memsize = "16384"
numvcpus = "8"
scsi0:0.fileName = "Oracle-Compute-$(printf "%02d" $new_num).vmdk"
ethernet0.connectionType = "custom"
ethernet0.vnet = "vmnet3"
EOF

      cat > user-data << EOF
#cloud-config
runcmd:
  - hostnamectl set-hostname oracle-compute-$(printf "%02d" $new_num)
  - sed -i 's/192.168.300.100/$new_ip/g' /etc/sysconfig/network-scripts/ifcfg-ens33
  - systemctl restart NetworkManager
  - mount -a
  - systemctl start oracle-xe-21c
  - systemctl enable oracle-xe-21c
EOF
      
      echo "instance-id: Oracle-Compute-$(printf "%02d" $new_num)" > meta-data
      genisoimage -output cloud-init.iso -volid cidata -joliet -rock user-data meta-data
      
      vmrun -T ws start "Oracle-Compute-$(printf "%02d" $new_num).vmx" nogui
      
      # Update load balancer
      ssh oracle@192.168.300.10 << EOF
echo "    server oracle-compute-$(printf "%02d" $new_num) $new_ip:1521 check" | sudo tee -a /etc/haproxy/haproxy.cfg
sudo systemctl reload haproxy
EOF
      
      echo "✅ Oracle scaled up: Oracle-Compute-$(printf "%02d" $new_num) added"
      ;;
      
    "scale_down")
      if [ $current_count -gt 2 ]; then
        local last_vm=$(ls $HOME/Virtual Machines/Oracle-Compute-* | tail -1 | basename)
        echo "📉 Scaling down Oracle: Removing $last_vm..."
        
        vmrun -T ws stop "$HOME/Virtual Machines/$last_vm/$last_vm.vmx"
        
        ssh oracle@192.168.300.10 << EOF
sudo sed -i "/$last_vm/d" /etc/haproxy/haproxy.cfg
sudo systemctl reload haproxy
EOF
        
        echo "✅ Oracle scaled down: $last_vm removed"
      fi
      ;;
  esac
}

# Auto-scaling MySQL compute
scale_mysql_compute() {
  local action=$1
  local current_count=$(ls $HOME/Virtual Machines/MySQL-Compute-* 2>/dev/null | wc -l)
  
  case $action in
    "scale_up")
      local new_num=$((current_count + 1))
      local new_ip="192.168.400.$((20 + new_num))"
      
      echo "🔥 Scaling up MySQL: Adding MySQL-Compute-$(printf "%02d" $new_num)..."
      
      mkdir -p "$HOME/Virtual Machines/MySQL-Compute-$(printf "%02d" $new_num)"
      cd "$HOME/Virtual Machines/MySQL-Compute-$(printf "%02d" $new_num)"
      
      cp "$MYSQL_COMPUTE_IMAGE" "MySQL-Compute-$(printf "%02d" $new_num).vmdk"
      
      cat > "MySQL-Compute-$(printf "%02d" $new_num).vmx" << EOF
.encoding = "UTF-8"
guestOS = "rhel9-64"
displayName = "MySQL-Compute-$(printf "%02d" $new_num)"
memsize = "8192"
numvcpus = "4"
scsi0:0.fileName = "MySQL-Compute-$(printf "%02d" $new_num).vmdk"
ethernet0.connectionType = "custom"
ethernet0.vnet = "vmnet4"
EOF

      cat > user-data << EOF
#cloud-config
runcmd:
  - hostnamectl set-hostname mysql-compute-$(printf "%02d" $new_num)
  - sed -i 's/192.168.400.100/$new_ip/g' /etc/sysconfig/network-scripts/ifcfg-ens33
  - systemctl restart NetworkManager
  - mount -a
  - systemctl start mysqld
  - systemctl enable mysqld
EOF
      
      echo "instance-id: MySQL-Compute-$(printf "%02d" $new_num)" > meta-data
      genisoimage -output cloud-init.iso -volid cidata -joliet -rock user-data meta-data
      
      vmrun -T ws start "MySQL-Compute-$(printf "%02d" $new_num).vmx" nogui
      
      # Update load balancer
      ssh root@192.168.400.10 << EOF
echo "    server mysql-compute-$(printf "%02d" $new_num) $new_ip:3306 check" | sudo tee -a /etc/haproxy/haproxy.cfg
sudo systemctl reload haproxy
EOF
      
      echo "✅ MySQL scaled up: MySQL-Compute-$(printf "%02d" $new_num) added"
      ;;
      
    "scale_down")
      if [ $current_count -gt 2 ]; then
        local last_vm=$(ls $HOME/Virtual Machines/MySQL-Compute-* | tail -1 | basename)
        echo "📉 Scaling down MySQL: Removing $last_vm..."
        
        vmrun -T ws stop "$HOME/Virtual Machines/$last_vm/$last_vm.vmx"
        
        ssh root@192.168.400.10 << EOF
sudo sed -i "/$last_vm/d" /etc/haproxy/haproxy.cfg
sudo systemctl reload haproxy
EOF
        
        echo "✅ MySQL scaled down: $last_vm removed"
      fi
      ;;
  esac
}

# Monitor and auto-scale based on load
auto_scale_all() {
  echo "🤖 Starting auto-scaling monitor..."
  
  while true; do
    echo "📊 Checking cluster loads..."
    
    # Check PostgreSQL load
    PG_CONNECTIONS=$(psql -h 192.168.200.10 -U postgres -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | tr -d ' ' || echo "0")
    echo "PostgreSQL connections: $PG_CONNECTIONS"
    
    if [ "$PG_CONNECTIONS" -gt 150 ]; then
      scale_postgres_compute "scale_up"
    elif [ "$PG_CONNECTIONS" -lt 30 ]; then
      scale_postgres_compute "scale_down"
    fi
    
    # Check Oracle load
    ORACLE_SESSIONS=$(sqlplus -s appuser/app123@192.168.300.10:1521/XE <<< "SELECT count(*) FROM v\$session; EXIT;" 2>/dev/null | tail -2 | head -1 | tr -d ' ' || echo "0")
    echo "Oracle sessions: $ORACLE_SESSIONS"
    
    if [ "$ORACLE_SESSIONS" -gt 80 ]; then
      scale_oracle_compute "scale_up"
    elif [ "$ORACLE_SESSIONS" -lt 20 ]; then
      scale_oracle_compute "scale_down"
    fi
    
    # Check MySQL load
    MYSQL_CONNECTIONS=$(mysql -h 192.168.400.200 -u root -p'MySQL123!' -e "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null | awk 'NR==2 {print $2}' || echo "0")
    echo "MySQL connections: $MYSQL_CONNECTIONS"
    
    if [ "$MYSQL_CONNECTIONS" -gt 400 ]; then
      scale_mysql_compute "scale_up"
    elif [ "$MYSQL_CONNECTIONS" -lt 50 ]; then
      scale_mysql_compute "scale_down"
    fi
    
    sleep 120  # Check every 2 minutes
  done
}

# Usage
case "$1" in
  "postgres")
    case "$2" in
      "up") scale_postgres_compute "scale_up" ;;
      "down") scale_postgres_compute "scale_down" ;;
      *) echo "Usage: $0 postgres {up|down}" ;;
    esac
    ;;
  "oracle")
    case "$2" in
      "up") scale_oracle_compute "scale_up" ;;
      "down") scale_oracle_compute "scale_down" ;;
      *) echo "Usage: $0 oracle {up|down}" ;;
    esac
    ;;
  "mysql")
    case "$2" in
      "up") scale_mysql_compute "scale_up" ;;
      "down") scale_mysql_compute "scale_down" ;;
      *) echo "Usage: $0 mysql {up|down}" ;;
    esac
    ;;
  "auto")
    auto_scale_all
    ;;
  *)
    echo "Usage: $0 {postgres|oracle|mysql} {up|down} | auto"
    echo "Examples:"
    echo "  $0 postgres up    # Scale up PostgreSQL compute"
    echo "  $0 oracle down    # Scale down Oracle compute"
    echo "  $0 mysql up       # Scale up MySQL compute"
    echo "  $0 auto           # Enable auto-scaling for all"
    ;;
esac