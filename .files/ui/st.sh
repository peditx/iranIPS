#!/bin/sh

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

# Install python3 and pip if not installed
#opkg update
#opkg install python3 python3-pip

# Install speedtest-cli using pip
pip3 install speedtest-cli

# Create necessary directories and files
echo "Creating necessary directories and files..."

# Create controller directories (if not exists)
mkdir -p /usr/lib/lua/luci/controller/nettools
mkdir -p /usr/lib/lua/luci/view/nettools

# Create speedtest.lua file for the controller
echo "Creating speedtest.lua..."
cat <<EOF > /usr/lib/lua/luci/controller/nettools/speedtest.lua
module("luci.controller.nettools.speedtest", package.seeall)

function index()
    if luci.http.formvalue("start_speedtest") then
        -- Run the speedtest only after pressing the Start button
        local speedtest = luci.sys.exec("python3 -m speedtest")

        -- Extract download, upload, and ping information
        local download = string.match(speedtest, "Download: (.+) Mbit/s")
        local upload = string.match(speedtest, "Upload: (.+) Mbit/s")
        local ping = string.match(speedtest, "Ping: (.+) ms")
        
        -- Display the results as JSON
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            download = download,
            upload = upload,
            ping = ping
        })
    else
        -- Show the HTML page with the Start button
        luci.template.render("nettools/speedtest")
    end
end
EOF

# Create speedtest.htm file for the view
echo "Creating speedtest.htm..."
cat <<EOF > /usr/lib/lua/luci/view/nettools/speedtest.htm
<%+header%>
<%+menu%>

<style>
    .result {
        font-size: 18px;
        font-weight: bold;
        margin-top: 20px;
    }
    .isp-info {
        font-size: 24px;
        font-weight: bold;
        text-align: center;
    }
    .start-button {
        display: block;
        margin: 20px auto;
        padding: 10px 20px;
        font-size: 18px;
        background-color: #4CAF50;
        color: white;
        border: none;
        cursor: pointer;
    }
    .start-button:hover {
        background-color: #45a049;
    }
</style>

<div class="isp-info">
    <p>ISP Name: <span id="isp-name">Loading...</span></p>
    <p>IP Address: <span id="ip-address">Loading...</span></p>
</div>

<button class="start-button" id="start-button">Start Speedtest</button>

<div class="result" id="result">
    <p id="download-speed">Download: N/A</p>
    <p id="upload-speed">Upload: N/A</p>
    <p id="ping-speed">Ping: N/A</p>
</div>

<script>
    // Function to fetch ISP and IP information
    function getISPInfo() {
        fetch('https://ipinfo.io/json')
            .then(response => response.json())
            .then(data => {
                document.getElementById('isp-name').textContent = data.org || 'Unknown ISP';
                document.getElementById('ip-address').textContent = data.ip || 'Unknown IP';
            })
            .catch(error => {
                console.error('Error fetching ISP info:', error);
                document.getElementById('isp-name').textContent = 'Error fetching ISP';
                document.getElementById('ip-address').textContent = 'Error fetching IP';
            });
    }

    // Send request to start the speedtest
    document.getElementById('start-button').addEventListener('click', function () {
        fetch('/cgi-bin/luci/admin/nettools/speedtest', {
            method: 'POST',
            body: new URLSearchParams({
                'start_speedtest': '1'
            })
        })
        .then(response => response.json())
        .then(data => {
            // Display speedtest results
            document.getElementById('download-speed').textContent = 'Download: ' + (data.download || 'N/A');
            document.getElementById('upload-speed').textContent = 'Upload: ' + (data.upload || 'N/A');
            document.getElementById('ping-speed').textContent = 'Ping: ' + (data.ping || 'N/A');
        })
        .catch(error => {
            console.error('Error starting speedtest:', error);
        });
    });

    // Call the function to load ISP info when the page loads
    window.onload = function() {
        getISPInfo();
    };
</script>

<%+footer%>
EOF

# Set permissions for the created files
echo "Setting file permissions..."
chmod -R 755 /usr/lib/lua/luci/controller/nettools/
chmod -R 755 /usr/lib/lua/luci/view/nettools/

# Restart uhttpd service to apply changes
echo "Restarting uhttpd service..."
/etc/init.d/uhttpd restart

echo "Installation completed successfully!"