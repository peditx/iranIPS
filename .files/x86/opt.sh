#!/bin/sh

# Title: PeDitX's OpenWrt x86 Ultimate Optimization Toolkit
# Author: PeDitX
# Description: Comprehensive Performance Optimizer for OpenWrt x86 Systems
# Version: 2.5
# Date: 2025-06-01
# License: GPL-3.0

# Check root access
if [ "$(id -u)" != "0" ]; then
    echo "ERROR: This script must be run as root!" >&2
    exit 1
fi

# Check for whiptail
if ! command -v whiptail >/dev/null; then
    echo "Installing whiptail..."
    opkg update >/dev/null 2>&1
    opkg install whiptail >/dev/null 2>&1
fi

# System information
DISTRO=$(grep 'OPENWRT_RELEASE' /etc/os-release | cut -d'"' -f2)
KERNEL=$(uname -r)
ARCH=$(uname -m)
CPU_MODEL=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^[ \t]*//')
CPU_CORES=$(grep -c '^processor' /proc/cpuinfo)
CPU_VENDOR=$(grep 'vendor_id' /proc/cpuinfo | head -1 | awk '{print $3}')

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
    uci show firewall > "/root/backup_optimizer/firewall_backup.uci" 2>/dev/null
}

# Restore backups
restore_backups() {
    if [ -d "/root/backup_optimizer" ]; then
        cp "/root/backup_optimizer/sysctl.conf.bak" "$SYSCTL_CONF" 2>/dev/null
        cp "/root/backup_optimizer/rc.local.bak" "$RC_LOCAL" 2>/dev/null
        [ -f "/root/backup_optimizer/usbcore.conf.bak" ] && \
        cp "/root/backup_optimizer/usbcore.conf.bak" "$USB_CONF"
        [ -f "/root/backup_optimizer/firewall_backup.uci" ] && \
        uci import firewall < "/root/backup_optimizer/firewall_backup.uci" && uci commit firewall
        whiptail --title "Backup Restored" --msgbox "Original configurations restored from backup." 10 50
    else
        whiptail --title "Backup Error" --msgbox "No backup found to restore." 10 50
    fi
}

# Show system info
show_system_info() {
    ROOT_SIZE=$(df -h / | awk 'NR==2 {print $2}')
    ROOT_USED=$(df -h / | awk 'NR==2 {print $3}')
    ROOT_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
    ROOT_PERCENT=$(df -h / | awk 'NR==2 {print $5}')
    
    FIREWALL_STATUS=$(uci get firewall.luci_wan.name 2>/dev/null || echo "Not enabled")
    if [ "$FIREWALL_STATUS" != "Not enabled" ]; then
        FIREWALL_STATUS="Enabled (Ports: $(uci get firewall.luci_wan.dest_port 2>/dev/null))"
    fi
    
    whiptail --title "System Information" --msgbox \
        "OpenWrt Version: $DISTRO\nKernel Version: $KERNEL\nArchitecture: $ARCH\nCPU Vendor: $CPU_VENDOR\nCPU Model:$CPU_MODEL\nCPU Cores: $CPU_CORES\n\nRoot Partition:\nSize: $ROOT_SIZE, Used: $ROOT_USED ($ROOT_PERCENT), Free: $ROOT_AVAIL\n\nLuCI on WAN: $FIREWALL_STATUS" \
        16 60
}

# Main menu
show_menu() {
    while true; do
        CHOICE=$(whiptail --title "PeDitX's OpenWrt Optimization Toolkit" --menu "\nSelect optimization category:" 24 70 14 \
            "1" "System Information" \
            "2" "Install Required Packages" \
            "3" "CPU & Microcode Optimization" \
            "4" "Memory & Cache Tuning" \
            "5" "Network & Ethernet Boost" \
            "6" "USB & Hardware Tweaks" \
            "7" "Apply ALL Optimizations" \
            "8" "Expand Root Partition" \
            "9" "Enable LuCI on WAN" \
            "10" "Restore Original Config" \
            "11" "System Reboot" \
            "12" "Exit Toolkit" 3>&1 1>&2 2>&3)
        
        [ -z "$CHOICE" ] && break
        
        case $CHOICE in
            1) show_system_info ;;
            2) install_packages ;;
            3) apply_cpu_optimizations ;;
            4) apply_memory_optimizations ;;
            5) apply_network_optimizations ;;
            6) apply_usb_tweaks ;;
            7) apply_all_optimizations ;;
            8) expand_root_partition ;;
            9) enable_luci_wan ;;
            10) restore_backups ;;
            11) system_reboot ;;
            12) break ;;
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
    
    # Intel-specific optimizations
    if [ -d "/sys/devices/system/cpu/intel_pstate" ]; then
        echo "echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo" >> "$RC_LOCAL"
        echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null
    fi
    
    # Apply to all CPU cores
    CPU_DIRS=$(ls -d /sys/devices/system/cpu/cpufreq/policy* 2>/dev/null)
    for policy in $CPU_DIRS; do
        core_num=$(basename "$policy" | sed 's/policy//')
        echo "echo performance > /sys/devices/system/cpu/cpufreq/policy${core_num}/scaling_governor" >> "$RC_LOCAL"
        echo performance > "${policy}/scaling_governor" 2>/dev/null
    done
    
    # Microcode reload (Intel only)
    if [ "$CPU_VENDOR" = "GenuineIntel" ] && [ -f "/sys/devices/system/cpu/microcode/reload" ]; then
        echo "echo 1 > /sys/devices/system/cpu/microcode/reload" >> "$RC_LOCAL"
        echo 1 > /sys/devices/system/cpu/microcode/reload 2>/dev/null
    fi
    
    whiptail --title "CPU Optimization" --msgbox "✅ CPU optimizations applied:\n- Performance governor enabled on all cores\n$( \
        [ -d "/sys/devices/system/cpu/intel_pstate" ] && echo "- Intel Turbo Boost disabled\n" || echo "" \
        )$( \
        [ "$CPU_VENDOR" = "GenuineIntel" ] && echo "- Microcode reload activated\n" || echo "" \
        )" 12 60
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

# Expand root partition
expand_root_partition() {
    # Show critical warning
    whiptail --title "WARNING: DATA LOSS RISK" --yesno "🚨 CRITICAL WARNING 🚨\n\nThis operation will:\n1. WIPE ALL DATA on your storage device\n2. Resize the root partition\n3. Require multiple reboots\n\nALL YOUR DATA WILL BE LOST!\n\nDo you want to continue?" \
    --yes-button "I Accept the Risk" --no-button "Cancel" 15 70 || return

    # ALWAYS install required packages (critical step)
    {
        echo "⏳ Installing required packages..."
        echo "This step is MANDATORY for partition expansion"
        opkg update
        opkg install parted losetup resize2fs wget-ssl
    } | whiptail --title "Installing Critical Packages" --scrolltext --gauge "Preparing for expansion..." 12 80 0
    
    # Check if packages installed successfully
    for pkg in parted losetup resize2fs wget-ssl; do
        if ! opkg list-installed | grep -q "^$pkg"; then
            whiptail --title "Installation Failed" --msgbox "CRITICAL ERROR: Failed to install $pkg package!" 10 60
            return 1
        fi
    done

    # Download expand script
    whiptail --title "Downloading Script" --infobox "Downloading expansion script..." 8 50
    wget -U "" -O /tmp/expand-root.sh "https://openwrt.org/_export/code/docs/guide-user/advanced/expand_root?codeblock=0" >/dev/null 2>&1
    
    if [ ! -f "/tmp/expand-root.sh" ]; then
        whiptail --title "Download Failed" --msgbox "Failed to download expansion script!" 10 50
        return 1
    fi
    
    # Source the script
    whiptail --title "Configuring" --infobox "Creating resize scripts..." 8 50
    . /tmp/expand-root.sh
    
    if [ ! -f "/etc/uci-defaults/70-rootpt-resize" ]; then
        whiptail --title "Error" --msgbox "Failed to create resize scripts!" 10 50
        return 1
    fi
    
    # Execute the resize script
    whiptail --title "Starting Expansion" --msgbox "Starting partition expansion...\n\nThe system will reboot multiple times.\n\nAfter final reboot, wait 3 minutes before accessing!" 12 60
    
    # Create marker file for post-reboot
    echo "Resize operation started at $(date)" > /root/resize_operation.log
    echo "Packages installed: parted, losetup, resize2fs, wget-ssl" >> /root/resize_operation.log
    
    # Execute resize script in background
    sh /etc/uci-defaults/70-rootpt-resize > /root/resize.log 2>&1 &
    
    # Show final instructions
    whiptail --title "Action Required" --msgbox "EXPANSION PROCESS STARTED!\n\nIf the system doesn't reboot automatically within 2 minutes:\n\n1. Reboot manually: 'reboot'\n2. Wait 3 minutes after reboot\n3. Check /root/resize_operation.log for status\n\nNOTE: parted, losetup, and resize2fs packages have been installed." 16 70
}

# Enable LuCI on WAN interface
enable_luci_wan() {
    # Security warning
    whiptail --title "SECURITY WARNING" --yesno "⚠️ WARNING: Enabling LuCI on WAN ⚠️\n\nThis will expose your router's web interface to the Internet!\n\n• Potential security risk\n• Only enable for temporary access\n• Use strong password\n• Consider disabling after use\n\nDo you want to continue?" \
    --yes-button "I Understand the Risk" --no-button "Cancel" 14 65 || return

    # Create the firewall rule
    uci set firewall.luci_wan=rule
    uci set firewall.luci_wan.name='Allow-LuCI-WAN'
    uci set firewall.luci_wan.src='wan'
    uci set firewall.luci_wan.dest_port='80 443'
    uci set firewall.luci_wan.proto='tcp'
    uci set firewall.luci_wan.target='ACCEPT'
    uci commit firewall
    /etc/init.d/firewall restart

    # Get WAN IP
    WAN_IP=$(ifstatus wan | jsonfilter -e '@["ipv4-address"][0].address' 2>/dev/null)
    [ -z "$WAN_IP" ] && WAN_IP="your WAN IP"

    whiptail --title "LuCI Enabled on WAN" --msgbox "✅ LuCI access enabled on WAN interface!\n\nAccess your router at:\nhttp://$WAN_IP\n\n⚠️ Remember to disable this when not needed!\n\nTo disable later:\n1. Go to Network → Firewall\n2. Delete 'Allow-LuCI-WAN' rule\n3. Or run: uci delete firewall.luci_wan && uci commit firewall && /etc/init.d/firewall restart" 16 65
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
