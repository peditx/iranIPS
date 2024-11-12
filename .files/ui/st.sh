#!/bin/sh

# Update packages and install prerequisites
opkg update
opkg install python3-pip
pip3 install speedtest-cli

# Download Net tools icon
mkdir -p /www/nettools-icon
wget -O /www/nettools-icon/nettools.png "https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/ui/button/vecteezy_network-sharing-circle-logo-icon_12986609.png"

# Create necessary directories for Lua controller files
mkdir -p /usr/lib/lua/luci/controller/nettools
mkdir -p /usr/lib/lua/luci/view/nettools

# Create Lua controller file for Nettools
cat << 'EOF' > /usr/lib/lua/luci/controller/nettools/nettools.lua
module("luci.controller.nettools.nettools", package.seeall)

function index()
    -- Add Net tools section to main menu
    local nettools = entry({"admin", "nettools"}, firstchild(), _("Net tools"), 60)
    nettools.icon_path = "/nettools-icon/nettools.png"
    nettools.icon = "nettools.png"
    nettools.index = true

    -- Add Speedtest option under Net tools
    entry({"admin", "nettools", "speedtest"}, template("nettools/speedtest"), _("Speedtest"), 10)
end
EOF

# Create Speedtest HTML template
cat << 'EOF' > /usr/lib/lua/luci/view/nettools/speedtest.htm
<%+header%>
    <h2>Speedtest</h2>
    <form action="/cgi-bin/luci/admin/nettools/speedtest" method="POST">
        <input type="submit" value="Start Speedtest" />
    </form>
    <br/>
    <div id="speedtest-results">
        <p><strong>Download Speed:</strong> <span id="download-speed" class="result-value">Loading...</span></p>
        <p><strong>Upload Speed:</strong> <span id="upload-speed" class="result-value">Loading...</span></p>
        <p><strong>Ping:</strong> <span id="ping" class="result-value">Loading...</span></p>
        <p><strong>Jitter:</strong> <span id="jitter" class="result-value">Loading...</span></p>
    </div>
    <br/>
    <footer>
        <p>Created by <a href="https://t.m/peditx" target="_blank">PeDitX</a></p>
    </footer>
    <style>
        #speedtest-results {
            font-size: 18px;
            margin-top: 20px;
        }
        .result-value {
            font-size: 22px;
            font-weight: bold;
            color: #4CAF50;
        }
        #download-speed {
            font-size: 26px;
            color: #2196F3;
        }
        #upload-speed {
            font-size: 26px;
            color: #FF9800;
        }
        #ping {
            font-size: 26px;
            color: #FF5722;
        }
        #jitter {
            font-size: 26px;
            color: #9C27B0;
        }
        footer {
            margin-top: 30px;
            text-align: center;
            font-size: 14px;
        }
        footer a {
            color: #007BFF;
            text-decoration: none;
        }
        footer a:hover {
            text-decoration: underline;
        }
    </style>
<%+footer%>
EOF

# Create script to run speedtest-cli and calculate jitter
cat << 'EOF' > /usr/lib/lua/luci/controller/nettools/speedtest.lua
module("luci.controller.nettools.speedtest", package.seeall)

function index()
    if luci.http.formvalue("start_speedtest") then
        -- Run speedtest
        local speedtest = luci.sys.exec("speedtest-cli --simple")
        local download = string.match(speedtest, "Download: (.+) Mbit/s")
        local upload = string.match(speedtest, "Upload: (.+) Mbit/s")
        local ping = string.match(speedtest, "Ping: (.+) ms")
        
        -- Calculate jitter using ping
        local jitter_command = "ping -c 10 8.8.8.8 | tail -n 10"
        local ping_results = luci.sys.exec(jitter_command)
        local ping_times = {}
        for time in string.gmatch(ping_results, "(%d+%.%d+)") do
            table.insert(ping_times, tonumber(time))
        end
        
        -- Calculate mean and variance
        local sum = 0
        for _, time in ipairs(ping_times) do
            sum = sum + time
        end
        local mean = sum / #ping_times
        
        local sum_of_squares = 0
        for _, time in ipairs(ping_times) do
            local diff = time - mean
            sum_of_squares = sum_of_squares + diff * diff
        end
        local variance = sum_of_squares / #ping_times
        local jitter = math.sqrt(variance)

        -- Send results to the page
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            download = download,
            upload = upload,
            ping = ping,
            jitter = string.format("%.2f", jitter)
        })
    else
        luci.template.render("nettools/speedtest")
    end
end
EOF

# Restart uhttpd to apply changes
/etc/init.d/uhttpd restart