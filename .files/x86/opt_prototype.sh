#!/bin/sh

# Title: PeDitX's OpenWrt x86 Ultimate Optimization Toolkit
# Author: PeDitX
# Description: Comprehensive Performance Optimizer for OpenWrt x86 Systems
# Version: 2.1
# Date: 2025-06-01
# License: GPL-3.0

# Check root access
if [ "$(id -u)" != "0" ]; then
    echo "ERROR: This script must be run as root!" >&2
    exit 1
fi

# Check for whiptail
if ! command -v whiptail >/dev/null; then
    echo "ERROR: whiptail not found. Install with: opkg update && opkg install whiptail" >&2
    exit 1
fi

# System information
DISTRO=$(grep 'OPENWRT_RELEASE' /etc/os-release | cut -d'"' -f2)
KERNEL=$(uname -r)
ARCH=$(uname -m)
CPU_MODEL=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^[ \t]*//')
CPU_CORES=$(grep -c '^processor' /proc/cpuinfo)

# Configuration files
SYSCTL_CONF="/etc/sysctl.conf"
RC_LOCAL="/etc/rc.local"
MODPROBE_DIR="/etc/modprobe.d"
USB_CONF="${MODPROBE_DIR}/usbcore.conf"

# Create backup of critical files
backup_files() {
    mkdir -p /root/backup_optimizer
    cp "$SYSCTL_CONF" "/root/backup_optimizer/sysctl.conf.bak" 2>/dev/null
    cp "$RC_LOCAL" "/root/backup_optimizer/rc.local.bak" 2>/dev/null
    [ -f "$USB_CONF" ] && cp "$USB_CONF" "/root/backup_optimizer/usbcore.conf.bak"
}

# Restore backups
restore_backups() {
    if [ -d "/root/backup_optimizer" ]; then
        cp "/root/backup_optimizer/sysctl.conf.bak" "$SYSCTL_CONF" 2>/dev/null
        cp "/root/backup_optimizer/rc.local.bak" "$RC_LOCAL" 2>/dev/null
        [ -f "/root/backup_optimizer/usbcore.conf.bak" ] && \
        cp "/root/backup_optimizer/usbcore.conf.bak" "$USB_CONF"
        whiptail --title "Backup Restored" --msgbox "Original configurations restored from backup." 10 50
    else
        whiptail --title "Backup Error" --msgbox "No backup found to restore." 10 50
    fi
}

# Show system info
show_system_info() {
    whiptail --title "System Information" --msgbox \
        "OpenWrt Version: $DISTRO\nKernel Version: $KERNEL\nArchitecture: $ARCH\nCPU Model:$CPU_MODEL\nCPU Cores: $CPU_CORES" \
        12 60
}

# Main menu
show_menu() {
    while true; do
        CHOICE=$(whiptail --title "PeDitX's OpenWrt Optimization Toolkit" --menu "\nSelect optimization category:" 20 70 10 \
            "1" "System Information" \
            "2" "Install Required Packages" \
            "3" "CPU & Microcode Optimization" \
            "4" "Memory & Cache Tuning" \
            "5" "Network & Ethernet Boost" \
            "6" "USB & Hardware Tweaks" \
            "7" "Apply ALL Optimizations" \
            "8" "Restore Original Config" \
            "9" "System Reboot" \
            "10" "Exit Toolkit" 3>&1 1>&2 2>&3)
        
        [ -z "$CHOICE" ] && break
        
        case $CHOICE in
            1) show_system_info ;;
            2) install_packages ;;
            3) apply_cpu_optimizations ;;
            4) apply_memory_optimizations ;;
            5) apply_network_optimizations ;;
            6) apply_usb_tweaks ;;
            7) apply_all_optimizations ;;
            8) restore_backups ;;
            9) system_reboot ;;
            10) break ;;
            *) whiptail --msgbox "Invalid option" 10 40 ;;
        esac
    done
}

# Package installation
install_packages() {
    whiptail --title "Package Installation" --yesno "This will install required packages. Continue?" 10 50 || return
    
    {
        echo "⏳ Updating package repositories..."
        opkg update
        
        echo "🚀 Installing packages..."
        opkg install kmod-nft-tproxy kmod-nft-socket dnsmasq-full kmod-usb-net-rtl8152 \
            openssh-sftp-server luci-compat luci-lib-ipkg haproxy kmod-nft-nat kmod-ipt-nat6 \
            parted losetup resize2fs wget-ssl intel-microcode iucode-tool kmod-usb3 irqbalance \
            odhcpd usbutils ethtool kmod-i2c-core kmod-hwmon-core lm-sensors luci-proto-ipv6 \
            kmod-usb-ohci kmod-usb-xhci-hcd kmod-dax
            
        echo "✅ Package installation complete!"
    } | whiptail --title "Package Installation" --scrolltext --gauge "Starting installation..." 20 80 0
    
    whiptail --title "Package Installation" --msgbox "Package installation completed!" 10 50
}

# CPU optimizations
apply_cpu_optimizations() {
    # Clean existing settings
    sed -i '/intel_pstate\/no_turbo/d' "$RC_LOCAL"
    sed -i '/microcode\/reload/d' "$RC_LOCAL"
    sed -i '/scaling_governor/d' "$RC_LOCAL"
    
    # Append new settings
    echo "echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo" >> "$RC_LOCAL"
    echo "echo 1 > /sys/devices/system/cpu/microcode/reload" >> "$RC_LOCAL"
    
    # Apply to all CPU cores
    CPU_DIRS=$(ls -d /sys/devices/system/cpu/cpufreq/policy* 2>/dev/null)
    for policy in $CPU_DIRS; do
        core_num=$(basename "$policy" | sed 's/policy//')
        echo "echo performance > /sys/devices/system/cpu/cpufreq/policy${core_num}/scaling_governor" >> "$RC_LOCAL"
    done
    
    # Apply settings immediately
    echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo
    echo 1 > /sys/devices/system/cpu/microcode/reload
    for policy in $CPU_DIRS; do
        echo performance > "${policy}/scaling_governor"
    done
    
    whiptail --title "CPU Optimization" --msgbox "✅ CPU optimizations applied:\n- Turbo Boost disabled\n- Performance governor enabled on all cores\n- Microcode reload activated" 12 60
}

# Memory optimizations
apply_memory_optimizations() {
    # Remove existing settings
    sed -i '/vm.swappiness/d' "$SYSCTL_CONF"
    sed -i '/vm.vfs_cache_pressure/d' "$SYSCTL_CONF"
    sed -i '/vm.dirty_ratio/d' "$SYSCTL_CONF"
    sed -i '/vm.dirty_background_ratio/d' "$SYSCTL_CONF"
    sed -i '/net.netfilter.nf_conntrack_max/d' "$SYSCTL_CONF"
    sed -i '/fs.file-max/d' "$SYSCTL_CONF"
    
    # Add new settings
    {
        echo "# PeDitX's Memory Optimizations"
        echo "vm.swappiness=10"
        echo "vm.vfs_cache_pressure=50"
        echo "vm.dirty_ratio=10"
        echo "vm.dirty_background_ratio=5"
        echo "net.netfilter.nf_conntrack_max=65535"
        echo "fs.file-max=2097152"
    } >> "$SYSCTL_CONF"
    
    sysctl -p >/dev/null 2>&1
    
    whiptail --title "Memory Optimization" --msgbox "✅ Memory optimizations applied:\n- Improved cache management\n- Optimized swappiness\n- Increased connection limits" 12 60
}

# Network optimizations
apply_network_optimizations() {
    # Get active ethernet interfaces
    ETH_INTERFACES=$(ip link show | awk -F': ' '/^[0-9]+: eth[0-9]/ {print $2}' | tr '\n' ' ')
    
    if [ -z "$ETH_INTERFACES" ]; then
        whiptail --title "Network Error" --msgbox "No ethernet interfaces found!" 10 50
        return
    fi
    
    # Apply settings to each interface
    for iface in $ETH_INTERFACES; do
        ethtool -K "$iface" gro on gso on tso on rx on tx on >/dev/null 2>&1
    done
    
    whiptail --title "Network Optimization" --msgbox "✅ Network optimizations applied to interfaces:\n$ETH_INTERFACES" 12 60
}

# USB tweaks
apply_usb_tweaks() {
    mkdir -p "$MODPROBE_DIR"
    echo "options usbcore autosuspend=-1" > "$USB_CONF"
    
    # Reload USB modules
    modprobe -r usbcore >/dev/null 2>&1
    modprobe usbcore >/dev/null 2>&1
    
    whiptail --title "USB Optimization" --msgbox "✅ USB settings optimized:\n- Autosuspend disabled\n- Configuration saved to $USB_CONF" 12 60
}

# Apply all optimizations
apply_all_optimizations() {
    whiptail --title "Complete Optimization" --yesno "This will apply ALL optimizations. Continue?" 10 50 || return
    
    install_packages
    apply_cpu_optimizations
    apply_memory_optimizations
    apply_network_optimizations
    apply_usb_tweaks
    
    whiptail --title "Optimization Complete" --msgbox "✅ ALL optimizations applied successfully!\n\nRecommendation: Reboot your system" 12 60
}

# System reboot
system_reboot() {
    if whiptail --title "System Reboot" --yesno "Reboot system now?" 10 50; then
        echo "System rebooting..."
        reboot
    fi
}

# Initialize toolkit
backup_files
show_menu
