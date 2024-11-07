#!/bin/sh

# Path to the footer.htm file
FOOTER_PATH="/usr/lib/lua/luci/view/themes/argon/footer.htm"

# Verify if the footer.htm file exists
if [ ! -f "$FOOTER_PATH" ]; then
    echo "footer.htm not found at $FOOTER_PATH, please check the path and try again."
    exit 1
fi

# Add CSS and HTML for floating button with local image in LuCI footer
cat << 'EOF' >> "$FOOTER_PATH"
<style>
    #floating-button {
        position: fixed;
        bottom: 20px;
        left: 20px;  /* Changed from right to left */
        width: 50px;
        height: 50px;
        border-radius: 50%;
        box-shadow: 0px 2px 10px rgba(0, 0, 0, 0.3);
        z-index: 1000;
        cursor: pointer;
        background-color: transparent;
    }

    #floating-button img {
        width: 100%;
        height: 100%;
        border-radius: 50%;
    }
</style>

<div id="floating-button" onclick="window.location.href='/cgi-bin/luci/admin/services/passwall2'">
    <img src="/luci-static/argon/img/argon.svg" alt="Monitoring Button">
</div>
EOF

# Restart uhttpd to apply changes
/etc/init.d/uhttpd restart

echo "Floating button added successfully. Please refresh LuCI to view the changes."
