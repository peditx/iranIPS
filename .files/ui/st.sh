#!/bin/sh

# Download the Net tools icon
mkdir -p /www/nettools-icon
wget -O /www/nettools-icon/nettools.png "https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/ui/button/vecteezy_network-sharing-circle-logo-icon_12986609.png"

# Create Lua controller for Nettools and Speedtest
cat << 'EOF' > /usr/lib/lua/luci/controller/nettools.lua
module("luci.controller.nettools", package.seeall)

function index()
    -- Add Net tools section to the main menu
    local nettools = entry({"admin", "nettools"}, firstchild(), _("Net tools"), 60)
    nettools.icon_path = "/nettools-icon/nettools.png"
    nettools.icon = "nettools.png"
    nettools.index = true

    -- Add Speedtest as a submenu under Net tools
    entry({"admin", "nettools", "speedtest"}, template("nettools/speedtest"), _("Speedtest"), 10)
end
EOF

# Create HTML template for Speedtest
mkdir -p /usr/lib/lua/luci/view/nettools
cat << 'EOF' > /usr/lib/lua/luci/view/nettools/speedtest.htm
<%+header%>
    <h2>Speedtest</h2>
    <iframe src="https://speed.cloudflare.com/" style="width:100%; height:80vh; border:none;"></iframe>
<%+footer%>
EOF

# Restart uhttpd to apply changes
/etc/init.d/uhttpd restart
