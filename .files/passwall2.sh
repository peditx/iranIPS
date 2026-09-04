#!/bin/sh
# Passwall 2 Installer for PeDitXOS (APK + OPKG)

echo ">>> Installing Passwall 2..."

# --- Detect Package Engine ---
PKG_ENGINE="opkg"
command -v apk >/dev/null 2>&1 && PKG_ENGINE="apk"

pkg_update() { [ "$PKG_ENGINE" = "apk" ] && apk update || opkg update; }
pkg_install() { [ "$PKG_ENGINE" = "apk" ] && apk add "$@" || opkg install "$@"; }
pkg_remove() { [ "$PKG_ENGINE" = "apk" ] && apk del "$@" || opkg remove --force-depends "$@"; }

# --- Install Packages ---
pkg_update > /dev/null 2>&1

pkg_remove dnsmasq > /dev/null 2>&1
pkg_install dnsmasq-full unzip luci-app-passwall2 ca-bundle kmod-tun > /dev/null 2>&1

# Verify
if [ -f /etc/init.d/passwall2 ]; then
    echo "[*] Passwall 2 installed successfully"
else
    echo "[!] Passwall 2 installation failed"
    exit 1
fi

# --- Install Xray ---
pkg_install xray-core > /dev/null 2>&1
if [ ! -f /usr/bin/xray ]; then
    echo "[!] Xray not found, trying temp install..."
    cd /tmp && wget -q https://github.com/peditx/iranIPS/raw/refs/heads/main/.files/lowspc/pedscript.sh && sh pedscript.sh > /dev/null 2>&1
fi

# --- Download hard.zip ---
wget -q https://github.com/peditx/iranIPS/raw/refs/heads/main/.files/hard.zip
unzip -o hard.zip -d / > /dev/null 2>&1
rm -f /tmp/hard.zip

# --- Configure ---
uci set passwall2.@global_forwarding[0]=global_forwarding
uci set passwall2.@global_forwarding[0].tcp_no_redir_ports='disable'
uci set passwall2.@global_forwarding[0].udp_no_redir_ports='disable'
uci set passwall2.@global_forwarding[0].tcp_redir_ports='1:65535'
uci set passwall2.@global_forwarding[0].udp_redir_ports='1:65535'
uci set passwall2.@global[0].remote_dns='8.8.4.4'

for rule in ProxyGame GooglePlay Netflix OpenAI Proxy China QUIC UDP; do
    uci delete passwall2.$rule 2>/dev/null
done

uci set passwall2.Direct=shunt_rules
uci set passwall2.Direct.network='tcp,udp'
uci set passwall2.Direct.remarks='IRAN'
uci set passwall2.Direct.ip_list='geoip:ir
0.0.0.0/8
10.0.0.0/8
100.64.0.0/10
127.0.0.0/8
169.254.0.0/16
172.16.0.0/12
192.0.0.0/24
192.0.2.0/24
192.88.99.0/24
192.168.0.0/16
198.19.0.0/16
198.51.100.0/24
203.0.113.0/24
224.0.0.0/4
240.0.0.0/4
255.255.255.255/32
::/128
::1/128
::ffff:0:0:0/96
64:ff9b::/96
100::/64
2001::/32
2001:20::/28
2001:db8::/32
2002::/16
fc00::/7
fe80::/10
ff00::/8'
uci set passwall2.Direct.domain_list='regexp:^.+\.ir$
geosite:category-ir
kifpool.me'

uci set passwall2.DirectGame=shunt_rules
uci set passwall2.DirectGame.network='tcp,udp'
uci set passwall2.DirectGame.remarks='PC-Direct'
uci set passwall2.DirectGame.ip_list=''
uci set passwall2.DirectGame.domain_list='nvidia.com
youtube.com
epicgames.com
meta.com
instagram.com
facebook.com
twitter.com
tiktok.com
spotify.com
capcut.com
adobe.com
ubisoft.com
google.com
x.com
bingx.com
mexc.com
openwrt.org
twitch.tv
asus.com
byteoversea.com
tiktokv.com
xbox.com
cloudflare.com
playstation.com
tradingview.com
telegram.com
telegram.org
microsoft.com
apps.microsoft.com
live.com
ytimg.com
t.me
whatsapp.com
reddit.com
discord.com
discord.gg
discordapp.net
discordapp.com
bing.com
steamcommunity.com
steam.com
steampowered.com
steamstatic.com
chatgpt.com
openai.com'

uci delete passwall2.myshunt 2>/dev/null
uci set passwall2.MainShunt=nodes
uci set passwall2.MainShunt.remarks='MainShunt'
uci set passwall2.MainShunt.type='Xray'
uci set passwall2.MainShunt.protocol='_shunt'
uci set passwall2.MainShunt.Direct='_direct'
uci set passwall2.MainShunt.DirectGame='_default'

uci set passwall2.PC_Shunt=nodes
uci set passwall2.PC_Shunt.remarks='PC-Shunt'
uci set passwall2.PC_Shunt.type='Xray'
uci set passwall2.PC_Shunt.protocol='_shunt'
uci set passwall2.PC_Shunt.Direct='_direct'
uci set passwall2.PC_Shunt.DirectGame='_default'

uci commit passwall2
/etc/init.d/passwall2 restart > /dev/null 2>&1

echo ">>> Passwall 2 done."
