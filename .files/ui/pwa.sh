#!/bin/bash

# Define variables
HEADER_FILE="/usr/lib/lua/luci/view/themes/argon/header.htm"
HEADER_LOGIN_FILE="/usr/lib/lua/luci/view/themes/argon/header_login.htm"
ICONS_ZIP_URL="https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/ui/favicon.zip"
TEMP_DIR="/tmp/touch-icons"
EXTRACT_DIR="/www/luci-static/argon/icons"
MANIFEST_FILE="/www/luci-static/argon/manifest.json"
SERVICE_WORKER_URL="https://example.com/service-worker.js"  # Update with your service worker URL

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

# Create the manifest.json file
echo "Creating manifest.json..."
cat > $MANIFEST_FILE <<EOL
{
  "name": "OpenWrt PWA App",
  "short_name": "OpenWrt PWA",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#4CAF50",
  "icons": [
    {
      "src": "/luci-static/argon/icons/icon-192x192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/luci-static/argon/icons/icon-512x512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
EOL

# Update the HTML header for PWA in header.htm
echo "Updating HTML header for PWA..."
sed -i 's|<%=media%>/icon/|/luci-static/argon/icons/|g' "$HEADER_FILE"
sed -i "s|</head>|<link rel=\"manifest\" href=\"/luci-static/argon/manifest.json\">\n<link rel=\"icon\" type=\"image/png\" sizes=\"192x192\" href=\"/luci-static/argon/icons/icon-192x192.png\">\n<link rel=\"icon\" type=\"image/png\" sizes=\"512x512\" href=\"/luci-static/argon/icons/icon-512x512.png\">\n<script src=\"$SERVICE_WORKER_URL\"></script>\n</head>|" "$HEADER_FILE"

# Update the HTML header for PWA in header_login.htm
echo "Updating login header for PWA..."
sed -i 's|<%=media%>/icon/|/luci-static/argon/icons/|g' "$HEADER_LOGIN_FILE"
sed -i "s|</head>|<link rel=\"manifest\" href=\"/luci-static/argon/manifest.json\">\n<link rel=\"icon\" type=\"image/png\" sizes=\"192x192\" href=\"/luci-static/argon/icons/icon-192x192.png\">\n<link rel=\"icon\" type=\"image/png\" sizes=\"512x512\" href=\"/luci-static/argon/icons/icon-512x512.png\">\n<script src=\"$SERVICE_WORKER_URL\"></script>\n</head>|" "$HEADER_LOGIN_FILE"

# Clean up temporary files
echo "Cleaning up temporary files..."
rm -rf $TEMP_DIR /tmp/touch-icons.zip

# Final message
echo "PWA setup completed successfully."
