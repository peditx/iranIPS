#!/bin/sh

# Full script for Passwall2 configuration

# Section 1: Remove unused rules to clean up the configuration
echo "Deleting extra rules..."
uci delete passwall2.ProxyGame
uci delete passwall2.GooglePlay
uci delete passwall2.Netflix
uci delete passwall2.OpenAI
uci delete passwall2.Proxy
uci delete passwall2.China
uci delete passwall2.QUIC
uci delete passwall2.UDP

# Section 2: Set up the Direct rule for Iran domains and IPs
echo "Setting up Direct rule for Iran..."
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
kifpool.me
geosite:category-bank-ir
geosite:category-finance
geosite:category-media-ir
geosite:category-news-ir
geosite:category-tech-ir
geosite:tld-!cn'

# Section 3: Configure the MainShunt node
echo "Configuring MainShunt node..."
# Delete previous MainShunt node if it exists to prevent errors
uci delete passwall2.MainShunt

# Create and configure the new MainShunt node
uci set passwall2.MainShunt=nodes
uci set passwall2.MainShunt.remarks='IRAN'
uci set passwall2.MainShunt.type='Xray'
uci set passwall2.MainShunt.protocol='_shunt'
uci set passwall2.MainShunt.Direct='_direct'
uci set passwall2.MainShunt.DirectGame='_default'

# Final Section: Commit all changes
echo "Saving changes..."
uci commit passwall2

# Display success message
echo "Configuration completed successfully."
echo "Restart the Passwall2 service to apply changes."

# Uncomment the line below for automatic service restart
# /etc/init.d/passwall2 restart

