# Storage-Compute Separation Architecture

## 🎯 **Mục Đích**
Tách biệt compute và storage để scaling độc lập như AWS RDS, Azure SQL, Google Cloud SQL.

## 🏗️ **Architecture Overview**

### **Current Monolithic vs New Separated**
```
Before (Monolithic):
VM1: [App + DB + Storage] - Hard to scale
VM2: [App + DB + Storage] - Waste resources
VM3: [App + DB + Storage] - Storage bottleneck

After (Separated):
Compute Layer:
├── DB-Compute-01 (CPU/RAM optimized)
├── DB-Compute-02 (Auto-scaling)
└── DB-Compute-N  (Scale based on load)

Storage Layer:
├── Shared-Storage-01 (NFS/iSCSI)
├── Shared-Storage-02 (Replication)
└── Backup-Storage    (Point-in-time recovery)
```

## 📊 **Network Architecture**

### **Storage Network (VMnet5: 192.168.500.0/24)**
```
Storage Cluster:
├── NFS-Primary (192.168.500.10) - Primary storage
├── NFS-Secondary (192.168.500.11) - Replica storage  
├── Backup-Server (192.168.500.20) - Backup storage
└── Storage-LB (192.168.500.5) - Storage load balancer
```

### **Compute Networks (Existing)**
```
PostgreSQL Compute (VMnet2: 192.168.200.0/24):
├── PG-Compute-01 (192.168.200.21) - Stateless
├── PG-Compute-02 (192.168.200.22) - Stateless
└── PG-LB (192.168.200.10) - Load balancer

Oracle Compute (VMnet3: 192.168.300.0/24):
├── Oracle-Compute-01 (192.168.300.21) - Stateless
├── Oracle-Compute-02 (192.168.300.22) - Stateless
└── Oracle-LB (192.168.300.10) - Load balancer

MySQL Compute (VMnet4: 192.168.400.0/24):
├── MySQL-Compute-01 (192.168.400.21) - Stateless
├── MySQL-Compute-02 (192.168.400.22) - Stateless
└── MySQL-LB (192.168.400.10) - Load balancer
```

## 💾 **Shared Storage Setup**

### **1. NFS Storage Golden Image**
```bash
#!/bin/bash
# build-storage-golden-image.sh

echo "Building Shared Storage Golden Image..."

VM_NAME="storage-golden-template"
./create-storage-vm.sh "$VM_NAME" "192.168.500.100" "16384" "8"

vmrun -T ws start "$HOME/Virtual Machines/$VM_NAME/$VM_NAME.vmx"
sleep 180

ssh root@192.168.500.100 << 'EOF'
# Install NFS and storage tools
dnf install -y nfs-utils nfs4-acl-tools
dnf install -y lvm2 xfsprogs rsync

# Install backup tools
dnf install -y bacula-storage bacula-client
dnf install -y borgbackup restic

# Install monitoring
dnf install -y node_exporter iostat iotop

# Create storage directories
mkdir -p /storage/{postgresql,oracle,mysql}
mkdir -p /backup/{postgresql,oracle,mysql}

# Create large storage volumes
pvcreate /dev/sdb /dev/sdc /dev/sdd
vgcreate storage_vg /dev/sdb /dev/sdc /dev/sdd
lvcreate -L 100G -n postgresql_lv storage_vg
lvcreate -L 100G -n oracle_lv storage_vg
lvcreate -L 100G -n mysql_lv storage_vg
lvcreate -L 200G -n backup_lv storage_vg

# Format with XFS
mkfs.xfs /dev/storage_vg/postgresql_lv
mkfs.xfs /dev/storage_vg/oracle_lv
mkfs.xfs /dev/storage_vg/mysql_lv
mkfs.xfs /dev/storage_vg/backup_lv

# Mount storage
echo "/dev/storage_vg/postgresql_lv /storage/postgresql xfs defaults 0 0" >> /etc/fstab
echo "/dev/storage_vg/oracle_lv /storage/oracle xfs defaults 0 0" >> /etc/fstab
echo "/dev/storage_vg/mysql_lv /storage/mysql xfs defaults 0 0" >> /etc/fstab
echo "/dev/storage_vg/backup_lv /backup xfs defaults 0 0" >> /etc/fstab
mount -a

# Configure NFS exports
tee /etc/exports << 'EXPORTS'
/storage/postgresql 192.168.200.0/24(rw,sync,no_root_squash,no_subtree_check)
/storage/oracle     192.168.300.0/24(rw,sync,no_root_squash,no_subtree_check)
/storage/mysql      192.168.400.0/24(rw,sync,no_root_squash,no_subtree_check)
/backup             192.168.0.0/16(rw,sync,no_root_squash,no_subtree_check)
EXPORTS

# Enable NFS
systemctl enable nfs-server
systemctl start nfs-server
exportfs -ra

# Configure firewall
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --permanent --add-service=mountd
firewall-cmd --reload

# Disable services for golden image
systemctl disable nfs-server

# Clean up
dnf clean all
rm -rf /var/log/* /tmp/* /var/tmp/*
history -c

echo "Storage Golden Image preparation completed"
EOF

# Create golden image
ssh root@192.168.500.100 "shutdown -h now"
sleep 120

cd "$HOME/Virtual Machines/$VM_NAME"
vmware-vdiskmanager -k "$VM_NAME.vmdk"

mkdir -p "$HOME/Golden-Images"
cp "$VM_NAME.vmdk" "$HOME/Golden-Images/storage-golden-$(date +%Y%m%d).vmdk"
ln -sf "storage-golden-$(date +%Y%m%d).vmdk" "$HOME/Golden-Images/storage-golden-latest.vmdk"

echo "Storage Golden Image created"
```

## 🖥️ **Stateless Compute Golden Images**

### **1. PostgreSQL Compute Golden Image**
```bash
#!/bin/bash
# build-postgres-compute-golden.sh

echo "Building PostgreSQL Compute Golden Image..."

VM_NAME="postgres-compute-template"
./create-ubuntu-vm.sh "$VM_NAME" "192.168.200.100" "8192" "4"

vmrun -T ws start "$HOME/Virtual Machines/$VM_NAME/$VM_NAME.vmx"
sleep 120

ssh ubuntu@192.168.200.100 << 'EOF'
# Install PostgreSQL (no local storage)
sudo apt update
sudo apt install -y postgresql-15 postgresql-client-15 postgresql-contrib-15

# Install NFS client
sudo apt install -y nfs-common

# Configure PostgreSQL to use NFS storage
sudo systemctl stop postgresql
sudo mkdir -p /mnt/postgres-data

# Configure NFS mount
echo "192.168.500.10:/storage/postgresql /mnt/postgres-data nfs defaults 0 0" | sudo tee -a /etc/fstab

# Configure PostgreSQL for NFS
sudo tee /etc/postgresql/15/main/postgresql.conf << 'PGCONF'
data_directory = '/mnt/postgres-data/main'
listen_addresses = '*'
port = 5432
max_connections = 200
shared_buffers = 2GB
wal_level = replica
max_wal_senders = 10
PGCONF

# Disable PostgreSQL (will be started per instance)
sudo systemctl disable postgresql

# Clean up
sudo apt autoremove -y
sudo rm -rf /var/log/* /tmp/* /var/tmp/*
history -c

echo "PostgreSQL Compute Golden Image ready"
EOF

# Create golden image
ssh ubuntu@192.168.200.100 "sudo shutdown -h now"
sleep 60

cd "$HOME/Virtual Machines/$VM_NAME"
vmware-vdiskmanager -k "$VM_NAME.vmdk"
cp "$VM_NAME.vmdk" "$HOME/Golden-Images/postgres-compute-golden-latest.vmdk"

echo "PostgreSQL Compute Golden Image created"
```

### **2. Auto-Scaling Compute Deployment**
```bash
#!/bin/bash
# auto-scale-compute.sh

COMPUTE_IMAGE="$HOME/Golden-Images/postgres-compute-golden-latest.vmdk"

# Auto-scaling function
scale_postgres_compute() {
  local action=$1  # scale_up or scale_down
  local current_count=$(ls $HOME/Virtual Machines/PG-Compute-* 2>/dev/null | wc -l)
  
  case $action in
    "scale_up")
      local new_num=$((current_count + 1))
      local new_ip="192.168.200.$((20 + new_num))"
      
      echo "Scaling up: Adding PG-Compute-$(printf "%02d" $new_num)..."
      
      # Deploy new compute instance
      mkdir -p "$HOME/Virtual Machines/PG-Compute-$(printf "%02d" $new_num)"
      cd "$HOME/Virtual Machines/PG-Compute-$(printf "%02d" $new_num)"
      
      cp "$COMPUTE_IMAGE" "PG-Compute-$(printf "%02d" $new_num).vmdk"
      
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
      
      echo "✅ Scaled up: PG-Compute-$(printf "%02d" $new_num) added"
      ;;
      
    "scale_down")
      if [ $current_count -gt 2 ]; then
        local last_vm=$(ls $HOME/Virtual Machines/PG-Compute-* | tail -1 | basename)
        echo "Scaling down: Removing $last_vm..."
        
        vmrun -T ws stop "$HOME/Virtual Machines/$last_vm/$last_vm.vmx"
        
        # Update load balancer
        ssh ubuntu@192.168.200.10 << EOF
sudo sed -i "/$last_vm/d" /etc/haproxy/haproxy.cfg
sudo systemctl reload haproxy
EOF
        
        echo "✅ Scaled down: $last_vm removed"
      else
        echo "⚠️ Minimum 2 compute instances required"
      fi
      ;;
  esac
}

# Auto-scaling based on load
auto_scale_postgres() {
  while true; do
    # Check average CPU across compute instances
    local total_cpu=0
    local instance_count=0
    
    for vm_dir in $HOME/Virtual Machines/PG-Compute-*; do
      if [ -d "$vm_dir" ]; then
        local vm_name=$(basename "$vm_dir")
        local vm_ip=$(echo "$vm_name" | sed 's/PG-Compute-/192.168.200.2/')
        
        local cpu_usage=$(ssh ubuntu@$vm_ip "top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1" 2>/dev/null || echo "0")
        total_cpu=$(echo "$total_cpu + $cpu_usage" | bc)
        instance_count=$((instance_count + 1))
      fi
    done
    
    if [ $instance_count -gt 0 ]; then
      local avg_cpu=$(echo "scale=2; $total_cpu / $instance_count" | bc)
      echo "Average CPU usage: ${avg_cpu}%"
      
      if (( $(echo "$avg_cpu > 80" | bc -l) )); then
        echo "🔥 High CPU detected, scaling up..."
        scale_postgres_compute "scale_up"
      elif (( $(echo "$avg_cpu < 20" | bc -l) )); then
        echo "📉 Low CPU detected, scaling down..."
        scale_postgres_compute "scale_down"
      fi
    fi
    
    sleep 60  # Check every minute
  done
}

# Usage
case "$1" in
  "up")
    scale_postgres_compute "scale_up"
    ;;
  "down")
    scale_postgres_compute "scale_down"
    ;;
  "auto")
    auto_scale_postgres
    ;;
  *)
    echo "Usage: $0 {up|down|auto}"
    ;;
esac
```

## 📊 **Benefits của Storage-Compute Separation**

### **Scaling Independence:**
```bash
# Scale compute only (CPU/RAM intensive workloads)
./auto-scale-compute.sh up

# Scale storage only (I/O intensive workloads)  
./add-storage-node.sh

# Scale both independently
./scale-cluster.sh compute=5 storage=3
```

### **Cost Optimization:**
```bash
# Compute instances: CPU/RAM optimized (smaller disks)
# Storage instances: I/O optimized (large disks, less CPU)

# Before: 3 VMs x (8GB RAM + 100GB disk) = 24GB RAM + 300GB disk
# After: 3 Compute (8GB RAM + 20GB disk) + 2 Storage (4GB RAM + 200GB disk)
#        = 24GB RAM + 460GB disk (more storage, same compute cost)
```

### **Enterprise Features:**
- 🔄 **Independent scaling** - Scale compute và storage riêng biệt
- 💾 **Shared storage** - Multiple compute instances access same data
- 📊 **Better resource utilization** - Right-size compute vs storage
- 🔒 **Centralized backup** - One backup system cho all databases
- ⚡ **Faster failover** - Compute instances stateless, quick restart

### **Production Deployment:**
```bash
# 1. Deploy storage layer first
./05-storage-compute-separation/scripts/deploy-storage-cluster.sh

# 2. Deploy stateless compute instances
./05-storage-compute-separation/scripts/deploy-compute-cluster.sh

# 3. Enable auto-scaling
./05-storage-compute-separation/scripts/auto-scale-compute.sh auto
```

Đây chính xác là architecture của **AWS RDS, Azure SQL Database, Google Cloud SQL** - tách biệt compute và storage để scaling optimal!