#!/bin/sh
# ============================================================================
# PeDitXOS First Boot Script — APK (OpenWrt 25+) — TEST VERSION
# Adapted from build.yml for manual testing on a running device
# ============================================================================
# Usage:
#   scp firstboot-apk-test.sh root@<device-ip>:/tmp/
#   ssh root@<device-ip> "sh /tmp/firstboot-apk-test.sh"
#
# This script performs the same actions as the uci-defaults script that runs
# on first boot. Run it on a LIVE device to verify behavior.
#
# WARNING: This WILL change UCI settings and restart services.
#          Make sure you can reach the device via serial/UART as a fallback.
#
# To REVERT changes:
#   uci revert system; uci revert network; uci revert dhcp
#   uci revert wireless; uci commit
#   /etc/init.d/dnsmasq restart
# ============================================================================

# ---- CONFIGURATION (test values for Linksys MX4300) ----
DEVICE_PROFILE="linksys_mx4300"
DEVICE_TARGET="qualcommax/ipq807x"
THEME_NAME="peditxos"

# ---- STEP 1: Fix time ----
echo "[1/8] Fixing system time..."
CURRENT_YEAR=$(date +%Y)
if [ "$CURRENT_YEAR" -lt 2024 ]; then
    date -s "2025-06-01 00:00:00" || echo "  WARNING: date set failed"
    hwclock -w 2>/dev/null || echo "  WARNING: hwclock write failed"
fi
echo "  Current date: $(date)"

# ---- STEP 2: APK allow-untrusted alias ----
echo "[2/8] Setting up APK --allow-untrusted alias..."
mkdir -p /etc/profile.d
echo "alias apk='apk --allow-untrusted'" > /etc/profile.d/apk-untrusted.sh
chmod 755 /etc/profile.d/apk-untrusted.sh
echo "  Done"

# ---- STEP 3: Nuke default repos ----
echo "[3/8] Checking default APK repositories..."
echo "  /etc/apk/repositories exists: $([ -f /etc/apk/repositories ] && echo YES || echo NO)"
echo "  /etc/apk/repositories.d contents:"
ls -la /etc/apk/repositories.d/ 2>/dev/null || echo "  (directory does not exist)"

# SAFETY: Only nuke if explicitly confirmed
echo ""
echo "  About to remove default repositories."
echo "  Press ENTER to continue or Ctrl+C to abort."
read -r _

rm -rf /etc/apk/repositories.d/*
rm -f /etc/apk/repositories
echo "  Default repos removed"

# ---- STEP 4: Write new repos (placeholder URLs for testing) ----
echo "[4/8] Writing test repository configuration..."
mkdir -p /etc/apk/repositories.d

# NOTE: These are TEST URLs. Replace with your actual repo URLs for full test.
# For now, just testing that the file is created correctly.
cat << CUSTOM_FEEDS_EOF > /etc/apk/repositories.d/customfeeds.list
# TEST: PeDitXOS custom feeds (placeholder)
# http://repository.peditxos.ir/openwrt-passwall-build/releases/packages-24.10/aarch64_cortex-a53/passwall_luci/packages.adb
# http://repository.peditxos.ir/openwrt-passwall-build/releases/packages-24.10/aarch64_cortex-a53/passwall_packages/packages.adb
# http://repository.peditxos.ir/openwrt-passwall-build/releases/packages-24.10/aarch64_cortex-a53/passwall2/packages.adb
CUSTOM_FEEDS_EOF

cat << REPO_EOF > /etc/apk/repositories.d/distfeeds.list
# TEST: Mirrored OpenWrt feeds (placeholder)
# http://repository.peditxos.ir/openwrt/releases/24.10.1/targets/qualcommax/ipq807x/packages/packages.adb
# http://repository.peditxos.ir/openwrt/releases/24.10.1/packages/aarch64_cortex-a53/base/packages.adb
REPO_EOF

# Aggregate
cat /etc/apk/repositories.d/distfeeds.list \
    /etc/apk/repositories.d/customfeeds.list > /etc/apk/repositories

echo "  Repository files created:"
ls -la /etc/apk/repositories.d/ 2>/dev/null
echo "  Aggregated file: /etc/apk/repositories ($(wc -l < /etc/apk/repositories) lines)"

# ---- STEP 5: UCI System Settings ----
echo "[5/8] Configuring UCI system settings..."
if command -v uci >/dev/null 2>&1; then
    echo "  UCI batch commands:"

    # Test each UCI command individually to find which ones fail
    echo "  - hostname..."
    uci -q set system.@system[0].hostname='PeDitXOS' && echo "    OK" || echo "    FAILED"

    echo "  - description..."
    uci -q set system.@system[0].description="PeDitXOS (Built for $DEVICE_PROFILE)" && echo "    OK" || echo "    FAILED"

    echo "  - zonename..."
    uci -q set system.@system[0].zonename='Asia/Tehran' && echo "    OK" || echo "    FAILED"

    echo "  - timezone..."
    uci -q set system.@system[0].timezone='<+0330>-3:30' && echo "    OK" || echo "    FAILED"

    echo "  - ntpserver..."
    uci -q set system.@system[0].ntpserver='ir.pool.ntp.org time.cloudflare.com' && echo "    OK" || echo "    FAILED"

    echo "  - wan dns..."
    uci -q set network.wan.dns='8.8.8.8 8.8.4.4' && echo "    OK" || echo "    FAILED"

    echo "  - lan ipaddr..."
    uci -q set network.lan.ipaddr='10.1.1.1' && echo "    OK" || echo "    FAILED"

    echo "  - luci mediaurlbase..."
    uci -q set luci.main.mediaurlbase="/luci-static/$THEME_NAME" && echo "    OK" || echo "    FAILED"
else
    echo "  WARNING: uci command not found!"
fi
echo ""

# ---- STEP 6: Wireless Configuration ----
echo "[6/8] Configuring wireless..."
if command -v uci >/dev/null 2>&1; then
    # Check all possible wireless section names
    echo "  Checking wireless sections..."

    FOUND_RADIO=false
    for iface in default_radio0 default_radio1 radio0 radio1; do
        if uci -q get wireless.$iface >/dev/null 2>&1; then
            echo "  Found: wireless.$iface"
            FOUND_RADIO=true

            # Get the device name from the interface
            DEVICE=$(uci -q get wireless.$iface.device 2>/dev/null)
            if [ -n "$DEVICE" ]; then
                echo "    Device: $DEVICE"
                uci -q set wireless.$DEVICE.disabled='0' && echo "    wireless.$DEVICE.disabled=0 -> OK" || echo "    FAILED"
            fi
            uci -q set wireless.$iface.disabled='0' && echo "    wireless.$iface.disabled=0 -> OK" || echo "    FAILED"
            uci -q set wireless.$iface.ssid='PeDitXOS' && echo "    wireless.$iface.ssid=PeDitXOS -> OK" || echo "    FAILED"
        fi
    done

    if [ "$FOUND_RADIO" = false ]; then
        echo "  WARNING: No wireless interfaces found!"
        echo "  Available wireless UCI sections:"
        uci -q show wireless 2>/dev/null | head -20 | sed 's/^/    /'
    fi

    echo "  Committing wireless..."
    uci commit wireless && echo "    OK" || echo "    FAILED"
else
    echo "  WARNING: uci command not found!"
fi
echo ""

# ---- STEP 7: DHCP Configuration ----
echo "[7/8] Configuring DHCP..."
if command -v uci >/dev/null 2>&1; then
    echo "  Checking dhcp sections..."

    if uci -q get dhcp.lan >/dev/null 2>&1; then
        echo "  dhcp.lan exists, configuring..."
        uci -q set dhcp.lan.ignore='0' && echo "    ignore=0 -> OK" || echo "    FAILED"
        uci -q set dhcp.lan.start='100' && echo "    start=100 -> OK" || echo "    FAILED"
        uci -q set dhcp.lan.limit='150' && echo "    limit=150 -> OK" || echo "    FAILED"
        uci -q set dhcp.lan.leasetime='12h' && echo "    leasetime=12h -> OK" || echo "    FAILED"
    else
        echo "  WARNING: dhcp.lan NOT found!"
        echo "  Available DHCP sections:"
        uci -q show dhcp 2>/dev/null | head -20 | sed 's/^/    /'
        echo "  DHCP will NOT work without dhcp.lan section!"
    fi

    echo "  Committing dhcp..."
    uci commit dhcp && echo "    OK" || echo "    FAILED"

    echo "  Committing all UCI changes..."
    uci commit && echo "    OK" || echo "    FAILED"
else
    echo "  WARNING: uci command not found!"
fi
echo ""

# ---- STEP 8: Service Restarts ----
echo "[8/8] Restarting services..."

echo "  Clearing LuCI cache..."
rm -rf /tmp/luci-cache/* 2>/dev/null && echo "    OK" || echo "    (no cache to clear)"

echo "  Restarting uhttpd..."
service uhttpd restart 2>/dev/null && echo "    OK" || echo "    FAILED (trying init.d)"
/etc/init.d/uhttpd restart 2>/dev/null && echo "    init.d restart OK" || echo "    init.d restart also FAILED"

echo "  Reloading config..."
/sbin/reload_config 2>/dev/null && echo "    OK" || echo "    FAILED"

echo "  Enabling dnsmasq..."
/etc/init.d/dnsmasq enable 2>/dev/null && echo "    OK" || echo "    FAILED"

echo "  Restarting dnsmasq..."
/etc/init.d/dnsmasq restart 2>/dev/null && echo "    OK" || echo "    FAILED"

echo ""
echo "  Checking dnsmasq status after restart..."
sleep 2
if pgrep -x dnsmasq >/dev/null 2>&1; then
    echo "  [OK] dnsmasq is running (PID: $(pgrep -x dnsmasq | head -1))"
else
    echo "  [FAIL] dnsmasq is NOT running!"
fi

if netstat -tulnp 2>/dev/null | grep -q ':53 ' || ss -tulnp 2>/dev/null | grep -q ':53 '; then
    echo "  [OK] Port 53 is listening"
else
    echo "  [FAIL] Port 53 is NOT listening"
fi

echo ""
echo "============================================="
echo " DONE — Check output above for any [FAIL] lines"
echo "============================================="
echo ""
echo "Current network state:"
echo "  LAN IP: $(uci -q get network.lan.ipaddr)"
echo "  DHCP range: $(uci -q get dhcp.lan.start) - $(($(uci -q get dhcp.lan.start) + $(uci -q get dhcp.lan.limit)))"
echo ""
echo "To verify DHCP is working, connect another device and check if it gets an IP."
echo ""
echo "To REVERT all changes:"
echo "  uci revert system; uci revert network; uci revert dhcp"
echo "  uci revert wireless; uci commit"
echo "  /etc/init.d/dnsmasq restart"
