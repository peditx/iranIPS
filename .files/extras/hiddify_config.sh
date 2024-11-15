#!/bin/bash

# Create necessary directories
echo "Creating necessary directories..."
mkdir -p /usr/lib/lua/luci/view/hiddify_config

# Create Lua script for Hiddify Config controller
echo "Creating Lua script for Hiddify Config controller ..."
cat <<EOF > /usr/lib/lua/luci/controller/hiddify_config.lua
module("luci.controller.hiddify_config", package.seeall)

function index()
    entry({"admin", "services", "hiddify_config"}, template("hiddify_config/hiddify_config"), "Hiddify Config", 10).leaf = true
    entry({"admin", "services", "hiddify_config", "download_config"}, call("handle_download"), nil).leaf = true
    entry({"admin", "services", "hiddify_config", "upload_config"}, call("handle_upload"), nil).leaf = true
end

function handle_download()
    local json_url = luci.http.formvalue("json_url")
    local temp_file = "/tmp/temp.json"
    local wg_config = "/wg.config"

    os.execute("wget -O " .. temp_file .. " " .. json_url .. " >/dev/null 2>&1")
    os.execute("mv " .. temp_file .. " " .. wg_config)

    luci.http.redirect(luci.dispatcher.build_url("admin", "services", "hiddify_config"))
end

function handle_upload()
    local file = luci.http.formvalue("json_file")
    local wg_config = "/wg.config"

    if file then
        local uploaded_file = "/tmp/uploaded.json"
        luci.http.setfilehandler(
            function(meta, chunk, eof)
                if not meta then return end
                if meta and chunk then
                    local fp = io.open(uploaded_file, "a")
                    fp:write(chunk)
                    fp:close()
                end
                if eof then
                    os.execute("mv " .. uploaded_file .. " " .. wg_config)
                end
            end
        )
    end

    luci.http.redirect(luci.dispatcher.build_url("admin", "services", "hiddify_config"))
end
EOF

# Create HTML file for Hiddify Config page
echo "Creating HTML file for Hiddify Config page ..."
cat <<EOF > /usr/lib/lua/luci/view/hiddify_config/hiddify_config.htm
<!DOCTYPE html>
<html>
<head>
    <title>Hiddify Config</title>
</head>
<body>
    <h1>Hiddify Config</h1>
    <form method="post" action="/cgi-bin/luci/admin/services/hiddify_config/download_config">
        <label for="json_url">Enter JSON URL:</label>
        <input type="text" id="json_url" name="json_url" required>
        <button type="submit">Download and Rename Config</button>
    </form>

    <form method="post" action="/cgi-bin/luci/admin/services/hiddify_config/upload_config" enctype="multipart/form-data">
        <label for="json_file">Upload JSON File:</label>
        <input type="file" id="json_file" name="json_file" required>
        <button type="submit">Upload and Rename Config</button>
    </form>
</body>
</html>
EOF

# Set permissions
echo "Setting permissions for Lua scripts and HTML files..."
chmod -R 755 /usr/lib/lua/luci/view/hiddify_config
chmod 755 /usr/lib/lua/luci/controller/hiddify_config.lua

# Restart uhttpd service
echo "Restarting uhttpd service ..."
/etc/init.d/uhttpd restart

echo "All tasks completed successfully!"
