#!/bin/bash

# Define variables
HEADER_FILE="/usr/lib/lua/luci/view/themes/argon/header.htm"
HEADER_LOGIN_FILE="/usr/lib/lua/luci/view/themes/argon/header_login.htm"
ICONS_ZIP_URL="https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/ui/favicon.zip"
TEMP_DIR="/tmp/touch-icons"
EXTRACT_DIR="/www/luci-static/argon/icons"
FAVICON_FILE="/www/luci-static/argon/favicon.ico"
MANIFEST_FILE="/www/luci-static/argon/manifest.json"

# Download the icons zip file
echo "Downloading PWA icons..."
wget -q "$ICONS_ZIP_URL" -O /tmp/touch-icons.zip

# Extract icons
echo "Extracting touch icons..."
unzip -q /tmp/touch-icons.zip -d $TEMP_DIR

# Create the destination directory if it doesn't exist
echo "Creating destination directory..."
mkdir -p $EXTRACT_DIR

# Move extracted icons to the destination directory
echo "Moving icons to destination..."
mv $TEMP_DIR/* $EXTRACT_DIR/

# Replace favicon.ico with the one from icons folder
echo "Replacing favicon.ico..."
cp "$EXTRACT_DIR/favicon.ico" "$FAVICON_FILE"

# Create the manifest.json file
echo "Creating manifest.json..."
cat > $MANIFEST_FILE <<EOL
{
  "name": "PeDitXrt PWA",
  "short_name": "PeDitXrt",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#4CAF50",
  "icons": [
    {
      "src": "/luci-static/argon/icons/icon-192x192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/luci-static/argon/icons/icon-512x512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/luci-static/argon/icons/apple-touch-icon.png",
      "sizes": "180x180",
      "type": "image/png"
    }
  ]
}
EOL

# Update the HTML header for PWA in header.htm
echo "Updating HTML header for PWA..."
sed -i 's|<%=media%>/icon/|/luci-static/argon/icons/|g' "$HEADER_FILE"
sed -i "s|</head>|<link rel=\"manifest\" href=\"/luci-static/argon/manifest.json\">\n<link rel=\"icon\" type=\"image/png\" sizes=\"192x192\" href=\"/luci-static/argon/icons/icon-192x192.png\">\n<link rel=\"icon\" type=\"image/png\" sizes=\"512x512\" href=\"/luci-static/argon/icons/icon-512x512.png\">\n<link rel=\"apple-touch-icon\" href=\"/luci-static/argon/icons/apple-touch-icon.png\">\n</head>|" "$HEADER_FILE"

# Update the HTML header for PWA in header_login.htm
echo "Updating login header for PWA..."
sed -i 's|<%=media%>/icon/|/luci-static/argon/icons/|g' "$HEADER_LOGIN_FILE"
sed -i "s|</head>|<link rel=\"manifest\" href=\"/luci-static/argon/manifest.json\">\n<link rel=\"icon\" type=\"image/png\" sizes=\"192x192\" href=\"/luci-static/argon/icons/icon-192x192.png\">\n<link rel=\"icon\" type=\"image/png\" sizes=\"512x512\" href=\"/luci-static/argon/icons/icon-512x512.png\">\n<link rel=\"apple-touch-icon\" href=\"/luci-static/argon/icons/apple-touch-icon.png\">\n</head>|" "$HEADER_LOGIN_FILE"

# Add a popup to login page with custom styling
echo "Adding popup to login page..."
cat >> /usr/lib/lua/luci/view/themes/argon/header_login.htm <<EOL
<script>
  // Check if the popup has already been shown
  if (!localStorage.getItem('pwa_popup_shown')) {
    // Function to show the popup
    function showPopup() {
      var popup = document.createElement("div");
      popup.id = "add-to-home-popup";
      popup.innerHTML = "<p>If you want to use this app as a native app, please add it to your home screen.</p><button onclick='this.parentElement.style.display=\"none\";'>Close</button>";
      
      // Apply the styles
      popup.style.position = "fixed";
      popup.style.left = "50%";
      popup.style.bottom = "20px";
      popup.style.transform = "translateX(-50%)";
      popup.style.backgroundColor = "rgba(0, 0, 0, 0.75)";
      popup.style.color = "#fff";
      popup.style.padding = "10px 20px";
      popup.style.borderRadius = "8px";
      popup.style.zIndex = "1000";
      popup.style.textAlign = "center";
      popup.style.boxShadow = "0 4px 8px rgba(0, 0, 0, 0.5)";
      
      document.body.appendChild(popup);
    }

    // Check if it's iOS and show the popup
    if (navigator.userAgent.match(/iPhone|iPad|iPod/)) {
      showPopup();
    }

    // Mark the popup as shown
    localStorage.setItem('pwa_popup_shown', 'true');
  }
</script>
EOL

# Clean up temporary files
echo "Cleaning up temporary files..."
rm -rf $TEMP_DIR /tmp/touch-icons.zip

# Final message
echo "PWA setup completed successfully."
