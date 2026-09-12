#!/bin/sh
# ============================================================================
# PeDitXOS First Boot Diagnostic Script
# Safe — READ-ONLY, no changes made to the device
# Run this BEFORE the actual firstboot script to identify issues
# ============================================================================
# Usage:
#   scp diagnose-firstboot.sh root@10.1.1.1:/tmp/
#   ssh root@10.1.1.1 "sh /tmp/diagnose-firstboot.sh"
# ============================================================================

echo "============================================="
echo " PeDitXOS First Boot Diagnostic"
echo " $(date)"
echo "============================================="
echo ""

ERRORS=0
WARNINGS=0

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo "  [WARN] $1"; WARNINGS=$((WARNINGS + 1)); }

# ---- 1. Check if UCI exists ----
echo "--- 1. UCI Availability ---"
if command -v uci >/dev/null 2>&1; then
    pass "uci binary found: $(which uci)"
else
    fail "uci binary NOT found"
fi
echo ""

# ---- 2. Check system section ----
echo "--- 2. System Section ---"
if uci -q get system.@system[0] >/dev/null 2>&1; then
    pass "system.@system[0] exists"
    echo "       hostname: $(uci -q get system.@system[0].hostname)"
    echo "       timezone: $(uci -q get system.@system[0].timezone)"
else
    fail "system.@system[0] NOT found"
fi
echo ""

# ---- 3. Check network sections ----
echo "--- 3. Network Sections ---"
echo "  Available network sections:"
uci -q show network 2>/dev/null | grep -E '^\network\.[a-z]' | head -20 | sed 's/^/    /'

echo ""
echo "  Checking specific sections used by firstboot script:"

# network.wan
if uci -q get network.wan >/dev/null 2>&1; then
    pass "network.wan exists"
else
    fail "network.wan NOT found — 'set network.wan.dns' will fail"
fi

# network.lan
if uci -q get network.lan >/dev/null 2>&1; then
    pass "network.lan exists"
    echo "       ipaddr: $(uci -q get network.lan.ipaddr)"
    echo "       proto:  $(uci -q get network.lan.proto)"
    echo "       type:   $(uci -q get network.lan.type)"
else
    fail "network.lan NOT found — 'set network.lan.ipaddr' will FAIL"
    echo "       >>> This is likely the cause of no DHCP on MX4300/MX4200!"
    # Check for alternative LAN sections
    LAN_ALT=$(uci -q show network 2>/dev/null | grep -E 'network\.(br-)?lan[0-9]*\.' | head -5)
    if [ -n "$LAN_ALT" ]; then
        echo "       Possible alternative LAN sections:"
        echo "$LAN_ALT" | sed 's/^/         /'
    fi
fi
echo ""

# ---- 4. Check DHCP sections ----
echo "--- 4. DHCP Sections ---"
echo "  Available DHCP sections:"
uci -q show dhcp 2>/dev/null | grep -E '^\dhcp\.[a-z]' | head -20 | sed 's/^/    /'

if uci -q get dhcp.lan >/dev/null 2>&1; then
    pass "dhcp.lan exists"
    echo "       ignore:    $(uci -q get dhcp.lan.ignore)"
    echo "       start:     $(uci -q get dhcp.lan.start)"
    echo "       limit:     $(uci -q get dhcp.lan.limit)"
    echo "       leasetime: $(uci -q get dhcp.lan.leasetime)"
else
    fail "dhcp.lan NOT found — 'set dhcp.lan.ignore/start/limit' will FAIL"
    echo "       >>> This is likely the cause of no DHCP on MX4300/MX4200!"
fi
echo ""

# ---- 5. Check wireless sections ----
echo "--- 5. Wireless Sections ---"
echo "  Available wireless sections:"
uci -q show wireless 2>/dev/null | grep -E '^\wireless\.[a-z]' | head -20 | sed 's/^/    /'

# Check for default_radio0 (what firstboot script looks for)
if uci -q get wireless.default_radio0 >/dev/null 2>&1; then
    pass "wireless.default_radio0 exists"
    echo "       disabled: $(uci -q get wireless.default_radio0.disabled)"
    echo "       ssid:     $(uci -q get wireless.default_radio0.ssid)"
else
    fail "wireless.default_radio0 NOT found — WiFi enable will be SKIPPED"
    # Check for alternative wireless interfaces
    WIFI_ALT=$(uci -q show wireless 2>/dev/null | grep -E 'wireless\.default_radio[0-9]+\.' | head -5)
    if [ -n "$WIFI_ALT" ]; then
        echo "       Possible alternative wireless interfaces:"
        echo "$WIFI_ALT" | sed 's/^/         /'
    fi
fi

# Check radio0 device
if uci -q get wireless.radio0 >/dev/null 2>&1; then
    pass "wireless.radio0 device exists"
    echo "       disabled: $(uci -q get wireless.radio0.disabled)"
else
    warn "wireless.radio0 device NOT found"
fi

# Check for radio1 (dual-band)
if uci -q get wireless.radio1 >/dev/null 2>&1; then
    pass "wireless.radio1 exists (dual-band device)"
else
    warn "wireless.radio1 NOT found (single-band or different naming)"
fi
echo ""

# ---- 6. Check LuCI section ----
echo "--- 6. LuCI Section ---"
if uci -q get luci.main >/dev/null 2>&1; then
    pass "luci.main exists"
    echo "       mediaurlbase: $(uci -q get luci.main.mediaurlbase)"
else
    fail "luci.main NOT found — 'set luci.main.mediaurlbase' will fail"
fi
echo ""

# ---- 7. Check dnsmasq ----
echo "--- 7. dnsmasq Status ---"
if command -v dnsmasq >/dev/null 2>&1; then
    pass "dnsmasq binary found: $(which dnsmasq)"
else
    fail "dnsmasq binary NOT found!"
fi

if /etc/init.d/dnsmasq enabled 2>/dev/null; then
    pass "dnsmasq is enabled"
else
    warn "dnsmasq is NOT enabled"
fi

if pgrep -x dnsmasq >/dev/null 2>&1; then
    pass "dnsmasq is running (PID: $(pgrep -x dnsmasq | head -1))"
else
    fail "dnsmasq is NOT running — DHCP will not work!"
fi

if netstat -tulnp 2>/dev/null | grep -q ':53 ' || ss -tulnp 2>/dev/null | grep -q ':53 '; then
    pass "Port 53 is in use (DNS listener active)"
else
    fail "Port 53 NOT in use — dnsmasq is not listening"
fi
echo ""

# ---- 8. Check APK vs OPKG ----
echo "--- 8. Package Manager ---"
if command -v apk >/dev/null 2>&1; then
    pass "APK detected (OpenWrt 25+)"
    echo "       apk path: $(which apk)"
    if [ -f /etc/apk/repositories ]; then
        echo "       repositories file exists"
        LINES=$(wc -l < /etc/apk/repositories)
        echo "       repository entries: $LINES"
    else
        warn "/etc/apk/repositories NOT found"
    fi
elif command -v opkg >/dev/null 2>&1; then
    pass "OPKG detected (OpenWrt 24.10 or older)"
else
    fail "Neither APK nor OPKG found"
fi
echo ""

# ---- 9. Check firmware info ----
echo "--- 9. Device Info ---"
if [ -f /etc/os-release ]; then
    echo "  $(grep PRETTY_NAME /etc/os-release 2>/dev/null)"
fi
if [ -f /etc/openwrt_release ]; then
    echo "  $(grep DISTRIB_DESCRIPTION /etc/openwrt_release 2>/dev/null)"
fi
echo "  Model: $(cat /tmp/sysinfo/model 2>/dev/null || echo 'unknown')"
echo "  Board: $(cat /tmp/sysinfo/board_name 2>/dev/null || echo 'unknown')"
echo ""

# ---- 10. Check if firstboot script already ran ----
echo "--- 10. First Boot Status ---"
if [ -f /etc/uci-defaults/98-peditxos-apk-settings ]; then
    warn "98-peditxos-apk-settings EXISTS in /etc/uci-defaults/ (will run on next boot)"
elif [ -f /etc/uci-defaults/99-peditxos-settings ]; then
    warn "99-peditxos-settings EXISTS in /etc/uci-defaults/ (will run on next boot)"
else
    pass "No PeDitXOS firstboot script found (not yet installed or already ran)"
fi

# Check marker file
if [ -f /etc/peditxos-booted ]; then
    pass "Marker file /etc/peditxos-booted exists (firstboot already completed)"
else
    warn "No marker file — firstboot has not completed yet"
fi
echo ""

# ---- Summary ----
echo "============================================="
echo " SUMMARY"
echo "============================================="
echo "  Errors:   $ERRORS"
echo "  Warnings: $WARNINGS"
echo ""
if [ $ERRORS -gt 0 ]; then
    echo "  *** $ERRORS ISSUE(S) FOUND — firstboot script will likely FAIL ***"
    echo "  Fix the [FAIL] items above before running the actual firstboot script."
else
    echo "  All checks passed. Firstboot script should work."
fi
echo "============================================="
