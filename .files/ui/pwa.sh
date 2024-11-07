#!/bin/bash

# Define variables
HEADER_FILE="/usr/lib/lua/luci/view/themes/argon/header.htm"
HEADER_LOGIN_FILE="/usr/lib/lua/luci/view/themes/argon/header_login.htm"
ICONS_ZIP_URL="https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/ui/favicon.zip"
TEMP_DIR="/tmp/touch-icons"
EXTRACT_DIR="/www/luci-static/argon/icons"
FAVICON_FILE="/www/luci-static/argon/favicon.ico"
MANIFEST_FILE="/www/luci-static/argon/manifest.json"
SERVICE_WORKER_FILE="/www/luci-static/argon/service-worker.js"

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
    },
    {
      "src": "/luci-static/argon/icons/icon-192x192.png",
      "sizes": "192x192",
      "type": "image/png"
    }
  ]
}
EOL

# Create the service-worker.js file
echo "Creating service-worker.js..."
cat > $SERVICE_WORKER_FILE <<EOL
// service-worker.js

const CACHE_NAME = 'openwrt-pwa-cache-v1';

const URLS_TO_CACHE = [
  '/',
  '/index.html',
  '/luci-static/argon/icons/icon-192x192.png',
  '/luci-static/argon/icons/icon-512x512.png',
  '/luci-static/argon/manifest.json',
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(URLS_TO_CACHE))
  );
});

self.addEventListener('activate', event => {
  const cacheWhitelist = [CACHE_NAME];
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (!cacheWhitelist.includes(cacheName)) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});

self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request)
      .then(response => response || fetch(event.request))
  );
});
EOL

# Update the HTML header for PWA in header.htm
echo "Updating HTML header for PWA..."
sed -i 's|<%=media%>/icon/|/luci-static/argon/icons/|g' "$HEADER_FILE"
sed -i "s|</head>|<link rel=\"manifest\" href=\"/luci-static/argon/manifest.json\">\n<link rel=\"icon\" type=\"image/png\" sizes=\"192x192\" href=\"/luci-static/argon/icons/icon-192x192.png\">\n<link rel=\"icon\" type=\"image/png\" sizes=\"512x512\" href=\"/luci-static/argon/icons/icon-512x512.png\">\n<link rel=\"apple-touch-icon\" href=\"/luci-static/argon/icons/apple-touch-icon.png\">\n<script src=\"/luci-static/argon/service-worker.js\"></script>\n</head>|" "$HEADER_FILE"

# Update the HTML header for PWA in header_login.htm
echo "Updating login header for PWA..."
sed -i 's|<%=media%>/icon/|/luci-static/argon/icons/|g' "$HEADER_LOGIN_FILE"
sed -i "s|</head>|<link rel=\"manifest\" href=\"/luci-static/argon/manifest.json\">\n<link rel=\"icon\" type=\"image/png\" sizes=\"192x192\" href=\"/luci-static/argon/icons/icon-192x192.png\">\n<link rel=\"icon\" type=\"image/png\" sizes=\"512x512\" href=\"/luci-static/argon/icons/icon-512x512.png\">\n<link rel=\"apple-touch-icon\" href=\"/luci-static/argon/icons/apple-touch-icon.png\">\n<script src=\"/luci-static/argon/service-worker.js\"></script>\n</head>|" "$HEADER_LOGIN_FILE"

# Clean up temporary files
echo "Cleaning up temporary files..."
rm -rf $TEMP_DIR /tmp/touch-icons.zip

# Final message
echo "PWA setup completed successfully."
