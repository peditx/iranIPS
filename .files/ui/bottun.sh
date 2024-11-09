#!/bin/sh

# Path to the footer.htm file
FOOTER_PATH="/usr/lib/lua/luci/view/themes/argon/footer.htm"

# Verify if the footer.htm file exists
if [ ! -f "$FOOTER_PATH" ]; then
    echo "footer.htm not found at $FOOTER_PATH, please check the path and try again."
    exit 1
fi

# Create the buttons folder if it doesn't exist
BUTTONS_FOLDER="/www/luci-static/argon/button"
mkdir -p "$BUTTONS_FOLDER"

# Download the image for the apple-touch-icon
IMAGE_URL_1="https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/ui/button/apple-touch-icon.png"
IMAGE_PATH_1="$BUTTONS_FOLDER/apple-touch-icon.png"

# Download the image for the passwall2 button
IMAGE_URL_2="https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/ui/button/passwall2.png"
IMAGE_PATH_2="$BUTTONS_FOLDER/passwall2.png"

# Download the image for the dashboard button
IMAGE_URL_3="https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/ui/button/rm.png"
IMAGE_PATH_3="$BUTTONS_FOLDER/rm.png"

# Download the image for the reboot button
IMAGE_URL_4="https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/ui/button/reboot.png"
IMAGE_PATH_4="$BUTTONS_FOLDER/reboot.png"

# Download the image for the telegram button
IMAGE_URL_5="https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/ui/button/tl.png"
IMAGE_PATH_5="$BUTTONS_FOLDER/tl.png"

# Use wget to download the images
echo "Downloading images..."
wget -q "$IMAGE_URL_1" -O "$IMAGE_PATH_1" && echo "Downloaded apple-touch-icon image" || echo "Failed to download apple-touch-icon image"
wget -q "$IMAGE_URL_2" -O "$IMAGE_PATH_2" && echo "Downloaded passwall2 image" || echo "Failed to download passwall2 image"
wget -q "$IMAGE_URL_3" -O "$IMAGE_PATH_3" && echo "Downloaded dashboard image" || echo "Failed to download dashboard image"
wget -q "$IMAGE_URL_4" -O "$IMAGE_PATH_4" && echo "Downloaded reboot image" || echo "Failed to download reboot image"
wget -q "$IMAGE_URL_5" -O "$IMAGE_PATH_5" && echo "Downloaded telegram image" || echo "Failed to download telegram image"

# Verify if the images were downloaded successfully
if [ ! -f "$IMAGE_PATH_1" ]; then
    echo "Failed to download image for apple-touch-icon from $IMAGE_URL_1"
    exit 1
fi

if [ ! -f "$IMAGE_PATH_2" ]; then
    echo "Failed to download image for passwall2 button from $IMAGE_URL_2"
    exit 1
fi

if [ ! -f "$IMAGE_PATH_3" ]; then
    echo "Failed to download image for dashboard button from $IMAGE_URL_3"
    exit 1
fi

if [ ! -f "$IMAGE_PATH_4" ]; then
    echo "Failed to download image for reboot button from $IMAGE_URL_4"
    exit 1
fi

if [ ! -f "$IMAGE_PATH_5" ]; then
    echo "Failed to download image for telegram button from $IMAGE_URL_5"
    exit 1
fi

# Add CSS and HTML for floating button with local image in LuCI footer
cat << EOF >> "$FOOTER_PATH"
<style>
    #floating-button {
        position: fixed;
        bottom: 20px;
        right: 20px;
        width: 80px;  /* Adjusted size */
        height: 80px;  /* Adjusted size */
        border-radius: 50%;
        box-shadow: 0px 2px 10px rgba(0, 0, 0, 0.3);
        z-index: 1000;
        cursor: pointer;
        background-color: transparent;
        border: none;
    }

    #floating-button img {
        width: 100%;
        height: 100%;
        border-radius: 50%;
        object-fit: cover; /* Make image cover the button */
    }

    .sub-buttons {
        position: fixed;
        bottom: -240px; /* Initially out of view, 3 icon sizes below */
        right: 20px;
        z-index: 999;
        flex-direction: column;
        display: flex;
        align-items: center;
        transform: translateY(100%); /* Initially out of view */
        transition: transform 0.3s ease-in-out;
        overflow: hidden;
    }

    .sub-buttons button {
        width: 80px;  /* Adjusted size */
        height: 80px;  /* Adjusted size */
        border-radius: 50%;
        border: none;
        background-color: #ffffff;
        box-shadow: 0px 2px 10px rgba(0, 0, 0, 0.3);
        cursor: pointer;
        margin-top: 10px;  /* Increased margin for more space between buttons */
        transition: transform 0.3s ease-in-out;
        overflow: hidden;
    }

    .sub-buttons button img {
        width: 100%;
        height: 100%;
        border-radius: 50%;
        object-fit: cover; /* Make image cover the button */
    }

    /* Custom colors for sub-buttons */
    .sub-buttons button.passwall2 {
        background-color: #29562e;
    }

    .sub-buttons button.reboot {
        background-color: #f55454;
    }

    .sub-buttons button.telegram {
        background-color: #00adec;
    }

    .sub-buttons button.dashboard {
        background-color: #29562e;
    }

    /* Animation for opening the buttons */
    .sub-buttons.open {
        bottom: 180px; /* Move 180px up when opened */
        transform: translateY(0);
    }
</style>

<div id="floating-button" onclick="toggleButtons()">
    <img src="/luci-static/argon/button/apple-touch-icon.png" alt="PeDitX Button">
</div>

<div class="sub-buttons" id="sub-buttons">
    <!-- Passwall2 Button -->
    <button class="passwall2" onclick="window.location.href='/cgi-bin/luci/admin/services/passwall2'">
        <img src="/luci-static/argon/button/passwall2.png" alt="Passwall2 Button">
    </button>
    <!-- Dashboard Button -->
    <button class="dashboard" onclick="window.location.href='/cgi-bin/luci/admin/status/overview'">
        <img src="/luci-static/argon/button/rm.png" alt="Dashboard Button">
    </button>
    <!-- Reboot Button -->
    <button class="reboot" onclick="window.location.href='/cgi-bin/luci/admin/system/reboot'">
        <img src="/luci-static/argon/button/reboot.png" alt="Reboot Button">
    </button>
    <!-- Telegram Button -->
    <button class="telegram" onclick="window.open('https://t.me/peditx', '_blank')">
        <img src="/luci-static/argon/button/tl.png" alt="Telegram Button">
    </button>
</div>

<script>
    function toggleButtons() {
        var subButtons = document.getElementById('sub-buttons');
        subButtons.classList.toggle('open');
    }
</script>
EOF

# Restart uhttpd to apply changes
/etc/init.d/uhttpd restart

echo "PeDitX button with sub-buttons added successfully. Please refresh LuCI to view the changes."
