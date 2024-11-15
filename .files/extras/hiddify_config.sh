#!/bin/sh

# Define file paths
HDCONF_DIR="/www/hdconf"
LUCI_CONTROLLER_DIR="/usr/lib/lua/luci/controller/vpn"
LUCI_VIEW_DIR="/usr/lib/lua/luci/view/vpn"
LUCI_API_DIR="/usr/lib/lua/luci/api"

# Create hdconf directory in /www/
echo "Creating hdconf directory in /www/ ..."
mkdir -p $HDCONF_DIR

# Set permissions for the directory
echo "Setting permissions for $HDCONF_DIR ..."
chmod 755 $HDCONF_DIR
chown -R www-data:www-data $HDCONF_DIR

# Create Lua script for downloading JSON file and renaming it
echo "Creating Lua script for downloading JSON file ..."
cat > $LUCI_CONTROLLER_DIR/download_config.lua << 'EOF'
local uci = require("luci.model.uci").cursor()
local fs = require("nixio.fs")

function download_config()
    local json_url = luci.http.formvalue("json_url")
    local temp_file = "/www/hdconf/temp.json"
    local wg_config = "/www/hdconf/wg.config"

    if fs.access(wg_config) then
        fs.remove(wg_config)
    end

    os.execute("wget -O " .. temp_file .. " " .. json_url)
    os.execute("mv " .. temp_file .. " " .. wg_config)

    luci.http.redirect(luci.dispatcher.build_url("admin/status"))
end

return download_config
EOF

# Create Lua script for uploading JSON file and renaming it
echo "Creating Lua script for uploading JSON file ..."
cat > $LUCI_CONTROLLER_DIR/upload_config.lua << 'EOF'
local uci = require("luci.model.uci").cursor()
local fs = require("nixio.fs")

function upload_config()
    local file = luci.http.formvalue("json_file")
    local wg_config = "/www/hdconf/wg.config"

    if fs.access(wg_config) then
        fs.remove(wg_config)
    end

    luci.http.write(file, "/www/hdconf/temp.json")
    os.execute("mv /www/hdconf/temp.json " .. wg_config)

    luci.http.redirect(luci.dispatcher.build_url("admin/status"))
end

return upload_config
EOF

# Create Lua file for Hiddify Config menu
echo "Creating Lua file for Hiddify Config menu ..."
cat > $LUCI_CONTROLLER_DIR/hiddify_config.lua << 'EOF'
module("luci.controller.vpn.hiddify_config", package.seeall)

function index()
    entry({"admin", "services", "vpn", "hiddify_config"}, alias("admin", "services", "vpn", "hiddify_config"), "Hiddify Config", 60).dependent = false
    entry({"admin", "services", "vpn", "hiddify_config", "index"}, template("vpn/hiddify_config"), nil).leaf = true
end
EOF

# Create HTML file for Hiddify Config page
echo "Creating HTML file for Hiddify Config page ..."
cat > $LUCI_VIEW_DIR/hiddify_config.htm << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenWrt VPN Hiddify Config</title>
    <style>
        body { font-family: Arial, sans-serif; direction: rtl; }
        .container { width: 60%; margin: 0 auto; padding: 20px; border: 1px solid #ccc; }
        h2 { text-align: center; }
        .menu-item { margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h2>OpenWrt VPN Hiddify Config</h2>
        <div id="luci-menu">
        </div>
        
        <h2>System Information</h2>
        <div id="system-info">
        </div>
    </div>

    <script>
        function loadLuciMenu() {
            fetch('/cgi-bin/luci/api/menu')
                .then(response => response.json())
                .then(data => {
                    const menuContainer = document.getElementById('luci-menu');
                    data.menu.forEach(menuItem => {
                        const div = document.createElement('div');
                        div.classList.add('menu-item');
                        div.textContent = menuItem.name;
                        menuContainer.appendChild(div);
                    });
                })
                .catch(error => console.error('Error loading menus:', error));
        }

        function loadSystemInfo() {
            fetch('/cgi-bin/luci/api/system')
                .then(response => response.json())
                .then(data => {
                    const systemInfoContainer = document.getElementById('system-info');
                    const uptime = document.createElement('div');
                    uptime.textContent = "Uptime: " + data.uptime;
                    systemInfoContainer.appendChild(uptime);
                    
                    const loadAvg = document.createElement('div');
                    loadAvg.textContent = "System Load Average: " + data.loadavg;
                    systemInfoContainer.appendChild(loadAvg);
                })
                .catch(error => console.error('Error loading system info:', error));
        }

        window.onload = function() {
            loadLuciMenu();
            loadSystemInfo();
        }
    </script>
</body>
</html>
EOF

# Restart uhttpd service
echo "Restarting uhttpd service ..."
/etc/init.d/uhttpd restart

echo "All tasks completed successfully!"
