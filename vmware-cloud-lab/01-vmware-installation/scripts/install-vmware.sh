#!/bin/bash

# VMware Workstation Auto Installation Script for Pop!_OS
# Author: VMware Cloud Lab
# Version: 1.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
VMWARE_VERSION="17.5.0-22583795"
DOWNLOAD_DIR="$HOME/Downloads/VMware"
VMWARE_URL="https://download3.vmware.com/software/WKST-1750-LX/VMware-Workstation-Full-${VMWARE_VERSION}.x86_64.bundle"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking system requirements..."
    
    # Check CPU virtualization
    if ! grep -E '(vmx|svm)' /proc/cpuinfo > /dev/null; then
        log_error "CPU virtualization not supported or not enabled in BIOS"
        exit 1
    fi
    
    # Check RAM (minimum 8GB recommended)
    RAM_GB=$(free -g | awk '/^Mem:/ {print $2}')
    if [ "$RAM_GB" -lt 8 ]; then
        log_warn "Less than 8GB RAM detected. VMware may run slowly."
    fi
    
    # Check disk space (minimum 50GB)
    DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$DISK_GB" -lt 50 ]; then
        log_error "Insufficient disk space. At least 50GB required."
        exit 1
    fi
    
    log_info "System requirements check passed"
}

update_system() {
    log_info "Updating Pop!_OS system..."
    sudo apt update && sudo apt upgrade -y
    
    log_info "Installing build dependencies..."
    sudo apt install -y \
        build-essential \
        linux-headers-$(uname -r) \
        gcc \
        make \
        curl \
        wget \
        git \
        dkms
}

check_secure_boot() {
    log_info "Checking Secure Boot status..."
    if command -v mokutil > /dev/null; then
        if mokutil --sb-state | grep -q "SecureBoot enabled"; then
            log_warn "Secure Boot is enabled. Consider disabling it for better VMware compatibility."
            log_warn "Reboot into BIOS and disable Secure Boot, then run this script again."
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
}

download_vmware() {
    log_info "Downloading VMware Workstation Pro..."
    
    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR"
    
    BUNDLE_FILE="VMware-Workstation-${VMWARE_VERSION}.bundle"
    
    if [ -f "$BUNDLE_FILE" ]; then
        log_info "VMware bundle already exists. Skipping download."
    else
        wget -O "$BUNDLE_FILE" "$VMWARE_URL"
        if [ $? -ne 0 ]; then
            log_error "Failed to download VMware Workstation"
            exit 1
        fi
    fi
    
    chmod +x "$BUNDLE_FILE"
    log_info "VMware Workstation downloaded successfully"
}

install_vmware() {
    log_info "Installing VMware Workstation..."
    
    cd "$DOWNLOAD_DIR"
    BUNDLE_FILE="VMware-Workstation-${VMWARE_VERSION}.bundle"
    
    # Install VMware
    sudo ./"$BUNDLE_FILE" --console --required --eulas-agreed
    
    if [ $? -ne 0 ]; then
        log_error "VMware installation failed"
        exit 1
    fi
    
    log_info "VMware Workstation installed successfully"
}

configure_kernel_modules() {
    log_info "Configuring kernel modules..."
    
    # Try to build kernel modules
    if ! sudo vmware-modconfig --console --install-all; then
        log_warn "Kernel module compilation failed. Trying community patches..."
        
        # Use community patches
        cd /tmp
        if [ -d "vmware-host-modules" ]; then
            rm -rf vmware-host-modules
        fi
        
        git clone https://github.com/mkubecek/vmware-host-modules.git
        cd vmware-host-modules
        
        # Checkout appropriate branch
        git checkout workstation-17.5.0
        
        # Build and install
        make
        sudo make install
        
        log_info "Community kernel modules installed"
    fi
}

configure_services() {
    log_info "Configuring VMware services..."
    
    # Enable and start VMware services
    sudo systemctl enable vmware
    sudo systemctl start vmware
    
    # Check service status
    if systemctl is-active --quiet vmware; then
        log_info "VMware services started successfully"
    else
        log_error "Failed to start VMware services"
        exit 1
    fi
}

configure_networks() {
    log_info "Configuring VMware networks..."
    
    # Configure custom networks
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
    
    log_info "VMware networks configured"
}

optimize_system() {
    log_info "Applying system optimizations..."
    
    # Optimize for virtualization
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    
    # Increase file descriptor limits
    echo '* soft nofile 65536' | sudo tee -a /etc/security/limits.conf
    echo '* hard nofile 65536' | sudo tee -a /etc/security/limits.conf
    
    # Enable KVM acceleration if available
    if lsmod | grep -q kvm; then
        sudo usermod -aG kvm $USER
        log_info "KVM acceleration enabled"
    fi
    
    # Apply changes
    sudo sysctl -p
    
    log_info "System optimizations applied"
}

create_directories() {
    log_info "Creating VMware directories..."
    
    # Create VM directory
    VM_DIR="$HOME/Virtual Machines"
    mkdir -p "$VM_DIR"
    
    # Create ISO directory
    ISO_DIR="$HOME/ISOs"
    mkdir -p "$ISO_DIR"/{Ubuntu,RHEL,Tools}
    
    log_info "Directories created:"
    log_info "  VMs: $VM_DIR"
    log_info "  ISOs: $ISO_DIR"
}

verify_installation() {
    log_info "Verifying VMware installation..."
    
    # Check VMware version
    if vmware --version > /dev/null 2>&1; then
        VERSION=$(vmware --version)
        log_info "VMware version: $VERSION"
    else
        log_error "VMware command not found"
        exit 1
    fi
    
    # Check VMware processes
    if pgrep vmware > /dev/null; then
        log_info "VMware processes are running"
    else
        log_warn "No VMware processes detected"
    fi
    
    # Check network interfaces
    if ip link show | grep -q vmnet; then
        log_info "VMware network interfaces detected"
    else
        log_warn "No VMware network interfaces found"
    fi
    
    log_info "Installation verification completed"
}

main() {
    echo "=========================================="
    echo "VMware Workstation Auto Installer"
    echo "Pop!_OS Edition"
    echo "=========================================="
    
    check_requirements
    update_system
    check_secure_boot
    download_vmware
    install_vmware
    configure_kernel_modules
    configure_services
    configure_networks
    optimize_system
    create_directories
    verify_installation
    
    echo "=========================================="
    log_info "VMware Workstation installation completed!"
    echo "=========================================="
    
    log_info "Next steps:"
    log_info "1. Reboot your system: sudo reboot"
    log_info "2. Start VMware: vmware &"
    log_info "3. Enter your license key"
    log_info "4. Create your first VM"
    
    log_warn "Note: You may need to log out and back in for group changes to take effect"
}

# Run main function
main "$@"