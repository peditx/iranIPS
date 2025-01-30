#!/bin/sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

clear

# Display the banner in magenta
echo -e "${MAGENTA}
 _______             _______   __    __      __    __         ______    ______  
|       \           |       \ |  \  |  \    |  \  |  \       /      \  /      \ 
| $$$$$$$\  ______  | $$$$$$$\ \$$ _| $$_   | $$  | $$      |  $$$$$$\|  $$$$$$\
| $$__/ $$ /      \ | $$  | $$|  \|   $$ \   \$$\/  $$      | $$  | $$| $$___\$$
| $$    $$|  $$$$$$\| $$  | $$| $$ \$$$$$$    >$$  $$       | $$  | $$ \$$    \ 
| $$$$$$$ | $$    $$| $$  | $$| $$  | $$ __  /  $$$$\       | $$  | $$ _\$$$$$$\
| $$      | $$$$$$$$| $$__/ $$| $$  | $$|  \|  $$ \$$\      | $$__/ $$|  \__| $$
| $$       \$$     \| $$    $$| $$   \$$  $$| $$  | $$       \$$    $$ \$$    $$
 \$$        \$$$$$$$ \$$$$$$$  \$$    \$$$$  \$$   \$$        \$$$$$$   \$$$$$$ 
                                                                                
                                                                                
                                                                                

                    P E D I T X    Repository   Repair  
${NC}"

# Remove old passwall keys and entries
rm -f /etc/opkg/keys/*passwall.pub
rm -f passwall.pub
sed -i '/master\.dl\.sourceforge\.net\/project\/openwrt-passwall-build/d' /etc/opkg/customfeeds.conf

# Download and add new passwall public key
wget -O passwall.pub https://repo.peditxdl.ir/passwall-packages/passwall.pub
opkg-key add passwall.pub

# Detect if system is SNAPSHOT version
SNNAP=$(grep -o SNAPSHOT /etc/openwrt_release | sed -n '1p')

if [ "$SNNAP" = "SNAPSHOT" ]; then
    echo -e "${YELLOW}SNAPSHOT Version Detected!${NC}"
    read arch << EOF
$(. /etc/openwrt_release ; echo $DISTRIB_ARCH)
EOF
    for feed in passwall_luci passwall_packages passwall2; do
        echo "src/gz $feed https://repo.peditxdl.ir/passwall-packages/snapshots/packages/$arch/$feed" >> /etc/opkg/customfeeds.conf
    done
else
    read release arch << EOF
$(. /etc/openwrt_release ; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF
    for feed in passwall_luci passwall_packages passwall2; do
        echo "src/gz $feed https://repo.peditxdl.ir/passwall-packages/releases/packages-$release/$arch/$feed" >> /etc/opkg/customfeeds.conf
    done
fi

# Update opkg feeds
opkg update

# Final messages with delays
echo -e "${MAGENTA}\nRepository successfully updated to PeDitX Repository${NC}"
sleep 3
echo -e "${MAGENTA}Made by PeDitX${NC}"
sleep 5
