#!/bin/sh
# Passwall 1 Installer for PeDitXOS (APK + OPKG)

echo ">>> Installing Passwall 1..."

# --- Detect Package Engine ---
PKG_ENGINE="opkg"
command -v apk >/dev/null 2>&1 && PKG_ENGINE="apk"

pkg_update() { [ "$PKG_ENGINE" = "apk" ] && apk update || opkg update; }
pkg_install() { [ "$PKG_ENGINE" = "apk" ] && apk add "$@" || opkg install "$@"; }
pkg_remove() { [ "$PKG_ENGINE" = "apk" ] && apk del "$@" || opkg remove --force-depends "$@"; }

# --- Install Packages ---
pkg_update > /dev/null 2>&1

pkg_remove dnsmasq > /dev/null 2>&1
pkg_install dnsmasq-full > /dev/null 2>&1
pkg_install luci-app-passwall > /dev/null 2>&1

# Verify
if [ -f /etc/init.d/passwall ]; then
    echo "[*] Passwall 1 installed successfully"
else
    echo "[!] Passwall 1 installation failed"
    exit 1
fi

# --- Install Xray ---
pkg_install xray-core > /dev/null 2>&1
if [ ! -f /usr/bin/xray ]; then
    echo "[!] Xray not found, trying temp install..."
    cd /tmp && wget -q https://github.com/peditx/iranIPS/raw/refs/heads/main/.files/lowspc/pedscript.sh && sh pedscript.sh > /dev/null 2>&1
fi

# --- Iran Bypass Rules ---
mkdir -p /usr/share/passwall/rules
cd /usr/share/passwall/rules/
wget -q https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/direct_ip
wget -q https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/direct_host
cd /tmp

# --- Download hard.zip ---
wget -q https://github.com/peditx/iranIPS/raw/refs/heads/main/.files/hard.zip
unzip -o hard.zip -d / > /dev/null 2>&1
rm -f /tmp/hard.zip

# --- Configure ---
uci set passwall.@global[0].tcp_proxy_mode='proxy'
uci set passwall.@global[0].udp_proxy_mode='proxy'
uci set passwall.@global_forwarding[0].tcp_no_redir_ports='disable'
uci set passwall.@global_forwarding[0].udp_no_redir_ports='disable'
uci set passwall.@global_forwarding[0].udp_redir_ports='1:65535'
uci set passwall.@global_forwarding[0].tcp_redir_ports='1:65535'
uci set passwall.@global[0].remote_dns='8.8.4.4'
uci set passwall.@global[0].dns_mode='udp'
uci set passwall.@global[0].chn_list='0'
uci commit passwall
/etc/init.d/passwall restart > /dev/null 2>&1

echo ">>> Passwall 1 done."
