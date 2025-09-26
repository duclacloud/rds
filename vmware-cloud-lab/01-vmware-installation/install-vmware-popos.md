# Cài Đặt VMware Workstation trên Pop!_OS

## 🎯 **Mục Đích**
Hướng dẫn chi tiết cài đặt VMware Workstation Pro trên Pop!_OS để tạo lab cloud testing.

## 🔧 **Chuẩn Bị Hệ Thống**

### **1. Kiểm Tra System Requirements**
```bash
# Kiểm tra CPU virtualization support
grep -E '(vmx|svm)' /proc/cpuinfo
echo "VT-x/AMD-V: $([ $(grep -E '(vmx|svm)' /proc/cpuinfo | wc -l) -gt 0 ] && echo 'Supported' || echo 'Not Supported')"

# Kiểm tra RAM và storage
echo "RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo "Available Disk: $(df -h / | awk 'NR==2 {print $4}')"

# Kiểm tra kernel version
uname -r
```

### **2. Update Pop!_OS**
```bash
# Full system update
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y build-essential linux-headers-$(uname -r) gcc make curl wget git

# Reboot if kernel updated
sudo reboot
```

### **3. Disable Secure Boot (Khuyến nghị)**
```bash
# Check Secure Boot status
mokutil --sb-state

# If enabled, disable in BIOS:
# 1. Reboot và nhấn F2/F12/Del vào BIOS
# 2. Tìm Security settings
# 3. Disable Secure Boot
# 4. Save và exit
```

## 📥 **Tải VMware Workstation**

### **1. Download VMware Workstation Pro**
```bash
# Tạo thư mục download
mkdir -p ~/Downloads/VMware
cd ~/Downloads/VMware

# Download VMware Workstation Pro 17.5.0
VMWARE_VERSION="17.5.0-22583795"
VMWARE_URL="https://download3.vmware.com/software/WKST-1750-LX/VMware-Workstation-Full-${VMWARE_VERSION}.x86_64.bundle"

wget -O "VMware-Workstation-${VMWARE_VERSION}.bundle" "$VMWARE_URL"

# Verify download
ls -lh VMware-Workstation-*.bundle
```

### **2. Chuẩn Bị Cài Đặt**
```bash
# Make executable
chmod +x VMware-Workstation-*.bundle

# Check file integrity
file VMware-Workstation-*.bundle
```

## 🚀 **Cài Đặt VMware**

### **1. Install VMware Workstation**
```bash
# Install VMware (GUI installer)
sudo ./VMware-Workstation-*.bundle

# Hoặc console mode
sudo ./VMware-Workstation-*.bundle --console --required --eulas-agreed
```

### **2. Post-Installation Setup**
```bash
# Start VMware services
sudo systemctl enable vmware
sudo systemctl start vmware

# Check service status
sudo systemctl status vmware

# Verify installation
vmware --version
```

## 🔧 **Fix Common Issues**

### **1. Kernel Module Compilation**
```bash
# If kernel modules fail to compile
sudo vmware-modconfig --console --install-all

# Alternative: Use community patches
cd /tmp
git clone https://github.com/mkubecek/vmware-host-modules.git
cd vmware-host-modules

# Checkout appropriate branch
git checkout workstation-17.5.0

# Build and install
make
sudo make install

# Restart VMware
sudo systemctl restart vmware
```

### **2. AppArmor Configuration**
```bash
# Check AppArmor status
sudo aa-status | grep vmware

# Create AppArmor profile for VMware
sudo tee /etc/apparmor.d/usr.bin.vmware << 'EOF'
#include <tunables/global>

/usr/bin/vmware {
  #include <abstractions/base>
  #include <abstractions/X>
  
  capability sys_rawio,
  capability sys_admin,
  
  /usr/bin/vmware mr,
  /usr/lib/vmware/** mr,
  /etc/vmware/** r,
  /tmp/** rw,
  /dev/vmnet* rw,
  
  owner @{HOME}/.vmware/** rw,
  owner @{HOME}/Virtual\ Machines/** rw,
}
EOF

# Load profile
sudo apparmor_parser -r /etc/apparmor.d/usr.bin.vmware
```

### **3. Network Configuration**
```bash
# Configure VMware networks
sudo vmware-netcfg

# Or manually configure
sudo tee -a /etc/vmware/networking << 'EOF'
answer VNET_1_DHCP yes
answer VNET_1_HOSTONLY_NETMASK 255.255.255.0
answer VNET_1_HOSTONLY_SUBNET 192.168.100.0
answer VNET_2_HOSTONLY_NETMASK 255.255.255.0
answer VNET_2_HOSTONLY_SUBNET 192.168.200.0
answer VNET_3_HOSTONLY_NETMASK 255.255.255.0
answer VNET_3_HOSTONLY_SUBNET 192.168.300.0
EOF

# Restart networking
sudo systemctl restart vmware-networks
```

## 🎫 **License Configuration**

### **1. License Setup**
```bash
# Start VMware GUI
vmware &

# Enter license key through GUI:
# Help -> Enter License Key

# Or use command line
sudo /usr/lib/vmware/bin/vmware-vmx --new-sn XXXXX-XXXXX-XXXXX-XXXXX-XXXXX

# Verify license
vmware -v
```

### **2. Initial Configuration**
```bash
# Set default VM directory
VM_DIR="$HOME/Virtual Machines"
mkdir -p "$VM_DIR"

# Configure VMware preferences
# Edit -> Preferences -> Workspace
# Set "Default location for virtual machines" to $VM_DIR
```

## 🛠️ **Performance Optimization**

### **1. System Tuning**
```bash
# Increase VM performance
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf

# Increase file descriptor limits
echo '* soft nofile 65536' | sudo tee -a /etc/security/limits.conf
echo '* hard nofile 65536' | sudo tee -a /etc/security/limits.conf

# Enable KVM acceleration (if available)
sudo modprobe kvm-intel  # or kvm-amd for AMD
sudo usermod -aG kvm $USER

# Apply changes
sudo sysctl -p
```

### **2. VMware Optimization**
```bash
# Create VMware optimization script
tee ~/bin/vmware-optimize.sh << 'EOF'
#!/bin/bash

# Stop unnecessary services
sudo systemctl stop bluetooth
sudo systemctl stop cups

# Set CPU governor to performance
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Disable swap (if enough RAM)
sudo swapoff -a

echo "VMware optimization applied"
EOF

chmod +x ~/bin/vmware-optimize.sh
```

## 🧪 **Verification Tests**

### **1. Test VMware Installation**
```bash
# Check VMware processes
ps aux | grep vmware

# Test VM creation
vmrun -T ws list

# Check network interfaces
ip link show | grep vmnet
```

### **2. Create Test VM**
```bash
# Create simple test VM
mkdir -p "$HOME/Virtual Machines/Test-VM"
cd "$HOME/Virtual Machines/Test-VM"

# Create minimal VMX file
cat > Test-VM.vmx << 'EOF'
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "19"
guestOS = "other"
displayName = "Test VM"
memsize = "1024"
numvcpus = "1"
EOF

# Test VM start
vmrun -T ws start Test-VM.vmx nogui
vmrun -T ws list
vmrun -T ws stop Test-VM.vmx
```

## 📋 **Installation Checklist**

- [ ] Pop!_OS updated to latest version
- [ ] Secure Boot disabled
- [ ] VMware Workstation downloaded
- [ ] VMware installed successfully
- [ ] Kernel modules compiled and loaded
- [ ] VMware services running
- [ ] License activated
- [ ] Networks configured
- [ ] AppArmor profiles created
- [ ] Performance optimizations applied
- [ ] Test VM created and verified

## 🔗 **Next Steps**
- [VMware Network Configuration](./vmware-configuration.md)
- [Create VM Templates](./vm-templates.md)
- [Ubuntu Cloud Setup](../02-ubuntu-cloud-postgres/ubuntu-cloud-setup.md)