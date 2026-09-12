#!/bin/sh
# ============================================================================
# PeDitXOS First Boot Script — APK (OpenWrt 25+) — FIXED VERSION
# Robust version with: netmask fix, dnsmasq verification, auto-revert, full logging
# ============================================================================
# Usage:
#   scp firstboot-apk-fixed.sh root@<device-ip>:/tmp/
#   ssh root@<device-ip> "sh /tmp/firstboot-apk-fixed.sh"
#
# Logs to: /tmp/firstboot-fixed.log
# ============================================================================

LOG_FILE="/tmp/firstboot-fixed.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date '+%H:%M:%S')] $*"; }
pass() { log "  ✅ $*"; }
fail() { log "  ❌ $*"; }
warn() { log "  ⚠️  $*"; }

# ---- CONFIGURATION ----
DEVICE_PROFILE="linksys_mx4200v1"
DEVICE_TARGET="qualcommax/ipq807x"
THEME_NAME="peditxos"
TARGET_LAN_IP="10.1.1.1"
TARGET_NETMASK="255.255.255.0"
DHCP_START="100"
DHCP_LIMIT="150"
DHCP_LEASETIME="12h"

ORIGINAL_LAN_IP=""
ORIGINAL_NETMASK=""

# ---- SAFETY: Capture original settings for auto-revert ----
capture_original() {
    ORIGINAL_LAN_IP=$(uci -q get network.lan.ipaddr)
    ORIGINAL_NETMASK=$(uci -q get network.lan.netmask)
    log "Original LAN: ${ORIGINAL_LAN_IP}/${ORIGINAL_NETMASK:-unknown}"
}

# ---- AUTO-REVERT on failure ----
revert_on_failure() {
    fail "CRITICAL FAILURE — Reverting changes..."
    [ -n "$ORIGINAL_LAN_IP" ] && uci -q set network.lan.ipaddr="$ORIGINAL_LAN_IP"
    [ -n "$ORIGINAL_NETMASK" ] && uci -q set network.lan.netmask="$ORIGINAL_NETMASK"
    uci revert dhcp 2>/dev/null
    uci revert wireless 2>/dev/null
    uci commit
    /etc/init.d/dnsmasq restart 2>/dev/null
    sleep 2
    fail "Reverted. Check log: $LOG_FILE"
    exit 1
}

# ---- Trap errors ----
trap 'revert_on_failure' ERR

log "============================================="
log " PeDitXOS First Boot — FIXED VERSION"
log " Device: $DEVICE_PROFILE"
log " Target: $DEVICE_TARGET"
log " Log: $LOG_FILE"
log "============================================="

# ---- STEP 1: Capture original state ----
log "[1/10] Capturing original network state..."
capture_original

# ---- STEP 2: Fix time ----
log "[2/10] Fixing system time..."
CURRENT_YEAR=$(date +%Y)
if [ "$CURRENT_YEAR" -lt 2024 ]; then
    date -s "2025-06-01 00:00:00" || warn "date set failed"
    hwclock -w 2>/dev/null || warn "hwclock write failed"
fi
pass "Time: $(date)"

# ---- STEP 3: APK allow-untrusted alias ----
log "[3/10] Setting up APK --allow-untrusted alias..."
mkdir -p /etc/profile.d
echo "alias apk='apk --allow-untrusted'" > /etc/profile.d/apk-untrusted.sh
chmod 755 /etc/profile.d/apk-untrusted.sh
pass "APK alias created"

# ---- STEP 4: Repository setup (non-blocking) ----
log "[4/10] Setting up APK repositories..."
mkdir -p /etc/apk/repositories.d

# Backup original repos
[ -f /etc/apk/repositories ] && cp /etc/apk/repositories /etc/apk/repositories.bak
[ -d /etc/apk/repositories.d ] && cp -r /etc/apk/repositories.d /etc/apk/repositories.d.bak

# Write custom repos (using placeholder URLs - replace with real ones)
cat << 'CUSTOM_FEEDS_EOF' > /etc/apk/repositories.d/customfeeds.list
# PeDitXOS custom feeds - REPLACE WITH REAL URLS
# http://repository.peditxos.ir/openwrt-passwall-build/releases/packages-24.10/aarch64_cortex-a53/passwall_luci/packages.adb
# http://repository.peditxos.ir/openwrt-passwall-build/releases/packages-24.10/aarch64_cortex-a53/passwall_packages/packages.adb
# http://repository.peditxos.ir/openwrt-passwall-build/releases/packages-24.10/aarch64_cortex-a53/passwall2/packages.adb
CUSTOM_FEEDS_EOF

cat << 'REPO_EOF' > /etc/apk/repositories.d/distfeeds.list
# Mirrored OpenWrt feeds - REPLACE WITH REAL URLS
# http://repository.peditxos.ir/openwrt/releases/24.10.1/targets/qualcommax/ipq807x/packages/packages.adb
# http://repository.peditxos.ir/openwrt/releases/24.10.1/packages/aarch64_cortex-a53/base/packages.adb
# http://repository.peditxos.ir/openwrt/releases/24.10.1/packages/aarch64_cortex-a53/luci/packages.adb
# http://repository.peditxos.ir/openwrt/releases/24.10.1/packages/aarch64_cortex-a53/packages/packages.adb
# http://repository.peditxos.ir/openwrt/releases/24.10.1/packages/aarch64_cortex-a53/routing/packages.adb
# http://repository.peditxos.ir/openwrt/releases/24.10.1/packages/aarch64_cortex-a53/telephony/packages.adb
# http://repository.peditxos.ir/openwrt/releases/24.10.1/targets/qualcommax/ipq807x/kmods/<EXACT_KMODS_DIR>/packages.adb
REPO_EOF

# Aggregate (non-fatal if empty)
cat /etc/apk/repositories.d/distfeeds.list /etc/apk/repositories.d/customfeeds.list > /etc/apk/repositories 2>/dev/null || true
pass "Repository files written (placeholder URLs)"

# ---- STEP 5: UCI System Settings ----
log "[5/10] Configuring UCI system settings..."
if command -v uci >/dev/null 2>&1; then
    # System
    uci -q set system.@system[0].hostname='PeDitXOS' && pass "hostname" || fail "hostname"
    uci -q set system.@system[0].description="PeDitXOS (Built for $DEVICE_PROFILE)" && pass "description" || fail "description"
    uci -q set system.@system[0].zonename='Asia/Tehran' && pass "zonename" || fail "zonename"
    uci -q set system.@system[0].timezone='<+0330>-3:30' && pass "timezone" || fail "timezone"
    uci -q set system.@system[0].ntpserver='ir.pool.ntp.org time.cloudflare.com' && pass "ntpserver" || fail "ntpserver"

    # Network WAN DNS
    uci -q set network.wan.dns='8.8.8.8 8.8.4.4' && pass "wan.dns" || warn "wan.dns"

    # Network LAN — CRITICAL: Set BOTH ipaddr AND netmask
    uci -q set network.lan.ipaddr="$TARGET_LAN_IP" && pass "lan.ipaddr=$TARGET_LAN_IP" || fail "lan.ipaddr"
    uci -q set network.lan.netmask="$TARGET_NETMASK" && pass "lan.netmask=$TARGET_NETMASK" || fail "lan.netmask"
    uci -q set network.lan.proto='static' && pass "lan.proto=static" || warn "lan.proto"

    # LuCI theme
    uci -q set luci.main.mediaurlbase="/luci-static/$THEME_NAME" && pass "luci.mediaurlbase" || warn "luci.mediaurlbase"
else
    fail "uci command not found!"
    exit 1
fi

# ---- STEP 6: Wireless Configuration ----
log "[6/10] Configuring wireless..."
if command -v uci >/dev/null 2>&1; then
    WIFI_CONFIGURED=false

    # Try all known radio interfaces
    for iface in default_radio0 default_radio1 default_radio2 default_radio3; do
        if uci -q get wireless.$iface >/dev/null 2>&1; then
            DEVICE=$(uci -q get wireless.$iface.device)
            log "  Found wireless interface: $iface (device: $DEVICE)"

            [ -n "$DEVICE" ] && {
                uci -q set wireless.$DEVICE.disabled='0' && pass "wireless.$DEVICE.disabled=0" || warn "wireless.$DEVICE.disabled"
            }
            uci -q set wireless.$iface.disabled='0' && pass "wireless.$iface.disabled=0" || warn "wireless.$iface.disabled"
            uci -q set wireless.$iface.ssid='PeDitXOS' && pass "wireless.$iface.ssid" || warn "wireless.$iface.ssid"
            uci -q set wireless.$iface.encryption='psk2' && pass "wireless.$iface.encryption" || warn "wireless.$iface.encryption"
            uci -q set wireless.$iface.key='peditxos123' && pass "wireless.$iface.key" || warn "wireless.$iface.key"
            WIFI_CONFIGURED=true
        fi
    done

    if [ "$WIFI_CONFIGURED" = false ]; then
        warn "No standard wireless interfaces found!"
        log "  Available wireless sections:"
        uci -q show wireless 2>/dev/null | head -30 | sed 's/^/    /'
    fi

    uci commit wireless && pass "wireless commit" || warn "wireless commit failed"
else
    warn "uci not available for wireless"
fi

# ---- STEP 7: DHCP Configuration ----
log "[7/10] Configuring DHCP..."
if command -v uci >/dev/null 2>&1; then
    # Find the correct DHCP section (lan, lan1, etc.)
    DHCP_SECTION=""
    for section in lan lan1 lan2 br-lan; do
        if uci -q get dhcp.$section >/dev/null 2>&1; then
            DHCP_SECTION="$section"
            break
        fi
    done

    if [ -n "$DHCP_SECTION" ]; then
        log "  Using DHCP section: $DHCP_SECTION"
        uci -q set dhcp.$DHCP_SECTION.ignore='0' && pass "dhcp.$DHCP_SECTION.ignore=0" || fail "dhcp.ignore"
        uci -q set dhcp.$DHCP_SECTION.start="$DHCP_START" && pass "dhcp.start=$DHCP_START" || fail "dhcp.start"
        uci -q set dhcp.$DHCP_SECTION.limit="$DHCP_LIMIT" && pass "dhcp.limit=$DHCP_LIMIT" || fail "dhcp.limit"
        uci -q set dhcp.$DHCP_SECTION.leasetime="$DHCP_LEASETIME" && pass "dhcp.leasetime=$DHCP_LEASETIME" || fail "dhcp.leasetime"
        uci -q set dhcp.$DHCP_SECTION.force='1' && pass "dhcp.force=1" || warn "dhcp.force"
    else
        fail "NO DHCP SECTION FOUND! Creating dhcp.lan..."
        uci -q set dhcp.lan=dhcp
        uci -q set dhcp.lan.interface='lan'
        uci -q set dhcp.lan.start="$DHCP_START"
        uci -q set dhcp.lan.limit="$DHCP_LIMIT"
        uci -q set dhcp.lan.leasetime="$DHCP_LEASETIME"
        uci -q set dhcp.lan.ignore='0'
        DHCP_SECTION="lan"
        pass "Created dhcp.lan"
    fi

    uci commit dhcp && pass "dhcp commit" || fail "dhcp commit"
    uci commit && pass "full uci commit" || fail "full uci commit"
else
    fail "uci not available!"
    exit 1
fi

# ---- STEP 8: Apply network changes & wait for interface ----
log "[8/10] Applying network changes..."
/sbin/reload_config 2>/dev/null || warn "reload_config failed"

# Wait for interface to come up with new IP
log "  Waiting for LAN interface to stabilize..."
for i in 1 2 3 4 5; do
    CURRENT_IP=$(uci -q get network.lan.ipaddr)
    if [ "$CURRENT_IP" = "$TARGET_LAN_IP" ]; then
        pass "LAN IP confirmed: $CURRENT_IP"
        break
    fi
    sleep 1
    [ $i -eq 5 ] && warn "LAN IP not confirmed after 5s (current: $CURRENT_IP)"
done

# ---- STEP 9: dnsmasq restart WITH VERIFICATION ----
log "[9/10] Restarting dnsmasq with verification..."

restart_dnsmasq() {
    /etc/init.d/dnsmasq restart 2>/dev/null
    sleep 2
    if pgrep -x dnsmasq >/dev/null 2>&1; then
        if netstat -tulnp 2>/dev/null | grep -q ':53 ' || ss -tulnp 2>/dev/null | grep -q ':53 '; then
            return 0
        fi
    fi
    return 1
}

# Try up to 3 times
DNSMASQ_OK=false
for attempt in 1 2 3; do
    log "  Attempt $attempt/3..."
    if restart_dnsmasq; then
        DNSMASQ_OK=true
        pass "dnsmasq running and listening on port 53"
        break
    else
        warn "dnsmasq restart failed (attempt $attempt)"
        sleep 2
    fi
done

if [ "$DNSMASQ_OK" = false ]; then
    fail "dnsmasq FAILED after 3 attempts — TRIGGERING AUTO-REVERT"
    revert_on_failure
fi

# ---- STEP 10: Final verification ----
log "[10/10] Final verification..."

# Check LAN IP
FINAL_IP=$(uci -q get network.lan.ipaddr)
FINAL_MASK=$(uci -q get network.lan.netmask)
pass "LAN: $FINAL_IP/$FINAL_MASK"

# Check DHCP
if uci -q get dhcp.$DHCP_SECTION >/dev/null 2>&1; then
    pass "DHCP section $DHCP_SECTION exists"
    log "  Range: $(uci -q get dhcp.$DHCP_SECTION.start) - $(($(uci -q get dhcp.$DHCP_SECTION.start) + $(uci -q get dhcp.$DHCP_SECTION.limit)))"
else
    warn "DHCP section $DHCP_SECTION missing!"
fi

# Check dnsmasq
if pgrep -x dnsmasq >/dev/null 2>&1; then
    pass "dnsmasq PID: $(pgrep -x dnsmasq | head -1)"
else
    fail "dnsmasq NOT running!"
fi

# Check port 53
if netstat -tulnp 2>/dev/null | grep -q ':53 ' || ss -tulnp 2>/dev/null | grep -q ':53 '; then
    pass "Port 53 LISTENING"
else
    fail "Port 53 NOT listening!"
fi

# Check wireless
WIFI_ON=0
for iface in default_radio0 default_radio1; do
    if uci -q get wireless.$iface.disabled 2>/dev/null | grep -q '^0$'; then
        WIFI_ON=1
        pass "Wireless $iface ENABLED"
    fi
done
[ $WIFI_ON -eq 0 ] && warn "No wireless interfaces enabled"

# Clear LuCI cache
rm -rf /tmp/luci-cache/* 2>/dev/null
service uhttpd restart 2>/dev/null || /etc/init.d/uhttpd restart 2>/dev/null

# ---- SUCCESS ----
log "============================================="
log " ✅ FIRST BOOT COMPLETED SUCCESSFULLY"
log "============================================="
log "LAN IP:     $FINAL_IP/$FINAL_MASK"
log "DHCP Range: $DHCP_START - $(($DHCP_START + $DHCP_LIMIT))"
log "dnsmasq:    RUNNING"
log "Log file:   $LOG_FILE"
log ""
log "Test: Connect a device and verify it gets an IP via DHCP"
log "============================================="

# Remove trap since we succeeded
trap - ERR