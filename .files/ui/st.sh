#!/bin/sh

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

# Install required packages
opkg update
opkg install curl python3 python3-pip

# Fetch Cloudflare Speed Test script
echo "Creating speedtest-cloudflare.sh script..."
cat <<EOF > /usr/lib/lua/luci/controller/speedtest-cloudflare.sh
#!/bin/sh

# Fetch the Cloudflare Speedtest results
result=\$(curl -s https://www.cloudflare.com/rate-limit)

# Extract the download, upload, and ping values
download=\$(echo "\$result" | grep -oP '"download":\s*\K[0-9.]+')
upload=\$(echo "\$result" | grep -oP '"upload":\s*\K[0-9.]+')
ping=\$(echo "\$result" | grep -oP '"latency":\s*\K[0-9.]+')

# Output the results in JSON format for the Luci page
echo '{"download": "'"$download"'", "upload": "'"$upload"'", "ping": "'"$ping"'"}'
EOF

# Set executable permissions for the script
chmod +x /usr/lib/lua/luci/controller/speedtest-cloudflare.sh

# Create the speedtest.lua controller for Luci
echo "Creating speedtest.lua controller..."
cat <<EOF > /usr/lib/lua/luci/controller/nettools/speedtest.lua
module("luci.controller.nettools.speedtest", package.seeall)

function index()
    entry({"admin", "nettools", "speedtest"}, cbi("nettools/speedtest"), _("Speedtest"), 60).dependent = false

    if luci.http.formvalue("start_speedtest") then
        -- Run the Cloudflare Speed Test script
        local result = luci.sys.exec("/usr/lib/lua/luci/controller/speedtest-cloudflare.sh")

        -- Parse the JSON result
        local json = require("luci.jsonc")
        local data = json.parse(result)

        -- Display the results as JSON
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            download = data.download,
            upload = data.upload,
            ping = data.ping
        })
    else
        -- Show the HTML page with the Start button
        luci.template.render("nettools/speedtest")
    end
end
EOF

# Create the speedtest.htm view for Luci
echo "Creating speedtest.htm view..."
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
    .footer {
        font-size: 14px;
        text-align: center;
        margin-top: 20px;
        font-weight: bold;
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

<div class="footer">
    Made by PeDitX
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