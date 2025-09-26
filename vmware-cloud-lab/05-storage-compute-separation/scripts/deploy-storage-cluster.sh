#!/bin/bash
# deploy-storage-cluster.sh - Deploy shared storage infrastructure

GOLDEN_IMAGE="$HOME/Golden-Images/storage-golden-latest.vmdk"

# Storage VMs configuration
declare -A STORAGE_VMS=(
  ["NFS-Primary"]="192.168.500.10:primary"
  ["NFS-Secondary"]="192.168.500.11:secondary"
  ["Backup-Server"]="192.168.500.20:backup"
)

deploy_storage_vm() {
  local vm_name=$1
  local ip=$2
  local role=$3
  
  echo "Deploying storage VM $vm_name..."
  
  mkdir -p "$HOME/Virtual Machines/$vm_name"
  cd "$HOME/Virtual Machines/$vm_name"
  
  # Clone golden image
  cp "$GOLDEN_IMAGE" "$vm_name.vmdk"
  
  # Add extra storage disks (100GB each)
  vmware-vdiskmanager -c -s 100GB -a lsilogic -t 1 "${vm_name}_data1.vmdk"
  vmware-vdiskmanager -c -s 100GB -a lsilogic -t 1 "${vm_name}_data2.vmdk"
  vmware-vdiskmanager -c -s 100GB -a lsilogic -t 1 "${vm_name}_data3.vmdk"
  
  # Create VMX with multiple disks
  cat > "$vm_name.vmx" << EOF
.encoding = "UTF-8"
guestOS = "rhel9-64"
displayName = "$vm_name"
memsize = "16384"
numvcpus = "8"
scsi0:0.fileName = "$vm_name.vmdk"
scsi0:1.fileName = "${vm_name}_data1.vmdk"
scsi0:2.fileName = "${vm_name}_data2.vmdk"
scsi0:3.fileName = "${vm_name}_data3.vmdk"
ethernet0.connectionType = "custom"
ethernet0.vnet = "vmnet5"
EOF

  # Role-specific cloud-init
  case $role in
    "primary")
      cat > user-data << 'EOF'
#cloud-config
runcmd:
  - hostnamectl set-hostname nfs-primary
  - sed -i 's/192.168.500.100/192.168.500.10/g' /etc/sysconfig/network-scripts/ifcfg-ens33
  - systemctl restart NetworkManager
  - systemctl enable nfs-server
  - systemctl start nfs-server
  - exportfs -ra
  - echo "NFS Primary storage ready" > /storage/status
EOF
      ;;
    "secondary")
      cat > user-data << 'EOF'
#cloud-config
runcmd:
  - hostnamectl set-hostname nfs-secondary
  - sed -i 's/192.168.500.100/192.168.500.11/g' /etc/sysconfig/network-scripts/ifcfg-ens33
  - systemctl restart NetworkManager
  - systemctl enable nfs-server
  - systemctl start nfs-server
  - sleep 60
  - rsync -av 192.168.500.10:/storage/ /storage/
  - echo "NFS Secondary storage ready" > /storage/status
EOF
      ;;
    "backup")
      cat > user-data << 'EOF'
#cloud-config
runcmd:
  - hostnamectl set-hostname backup-server
  - sed -i 's/192.168.500.100/192.168.500.20/g' /etc/sysconfig/network-scripts/ifcfg-ens33
  - systemctl restart NetworkManager
  - systemctl enable bacula-sd
  - systemctl start bacula-sd
  - echo "Backup server ready" > /backup/status
EOF
      ;;
  esac
  
  echo "instance-id: $vm_name" > meta-data
  genisoimage -output cloud-init.iso -volid cidata -joliet -rock user-data meta-data
  
  vmrun -T ws start "$vm_name.vmx" nogui
  echo "$vm_name started"
}

# Deploy storage cluster
echo "🗄️ Deploying shared storage cluster..."

for vm_config in "${!STORAGE_VMS[@]}"; do
  IFS=':' read -r ip role <<< "${STORAGE_VMS[$vm_config]}"
  deploy_storage_vm "$vm_config" "$ip" "$role" &
done

wait

echo "⏳ Waiting for storage services to initialize..."
sleep 180

# Verify storage cluster
echo "🔍 Verifying storage cluster..."

# Test NFS mounts
if showmount -e 192.168.500.10 &>/dev/null; then
  echo "✅ NFS Primary accessible"
else
  echo "❌ NFS Primary issues"
fi

if showmount -e 192.168.500.11 &>/dev/null; then
  echo "✅ NFS Secondary accessible"
else
  echo "❌ NFS Secondary issues"
fi

echo "✅ Storage cluster deployment completed!"
echo "📊 NFS Exports available:"
echo "  - PostgreSQL: 192.168.500.10:/storage/postgresql"
echo "  - Oracle: 192.168.500.10:/storage/oracle"
echo "  - MySQL: 192.168.500.10:/storage/mysql"
echo "  - Backup: 192.168.500.20:/backup"