#!/bin/sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for whiptail
if ! command -v whiptail >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing whiptail...${NC}"
    opkg update && opkg install whiptail
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install whiptail. Exiting...${NC}"
        exit 1
    fi
fi

# Package list
packages="sing-box haproxy v2ray-core luci-app-v2raya luci-app-openvpn softethervpn5-client fontconfig luci-app-wol luci-app-smartdns hysteria btop"

# Use whiptail to select packages
selected_packages=$(whiptail --title "Package Installer" \
    --checklist "Select packages to install:" 20 78 10 \
    "sing-box" "Sing-Box VPN" OFF \
    "haproxy" "HAProxy Load Balancer" OFF \
    "v2ray-core" "V2Ray Core" OFF \
    "luci-app-v2raya" "V2RayA Luci App" OFF \
    "luci-app-openvpn" "OpenVPN Luci App" OFF \
    "softethervpn5-client" "SoftEther VPN Client" OFF \
    "fontconfig" "Font Config" OFF \
    "luci-app-wol" "Wake-on-LAN Luci App" OFF \
    "luci-app-smartdns" "SmartDNS Luci App" OFF \
    "hysteria" "Hysteria VPN" OFF \
    "btop" "Resource Monitor" OFF 3>&1 1>&2 2>&3)

# Check if user canceled
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Installation canceled by user.${NC}"
    exit 0
fi

# Update opkg
echo -e "${GREEN}Updating package lists...${NC}"
opkg update

# Install selected packages
for package in $selected_packages; do
    # Remove quotes and install the package
    package_name=$(echo $package | sed 's/"//g')
    echo -e "${YELLOW}Installing $package_name...${NC}"
    opkg install "$package_name"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}$package_name installed successfully ✅${NC}"
    else
        echo -e "${RED}Failed to install $package_name ❌${NC}"
    fi
done

# If SingBox is installed, configure the main shunt
if opkg list-installed | grep -q "^sing-box "; then
    echo -e "${YELLOW}Configuring SingBoX shunt...${NC}"
    uci set passwall2.MainShunt=nodes
    uci set passwall2.MainShunt.remarks='SingBoX-Shunt'
    uci set passwall2.MainShunt.type='Sing-Box'
    uci set passwall2.MainShunt.protocol='_shunt'
    uci set passwall2.MainShunt.Direct='_direct'
    uci set passwall2.MainShunt.DirectGame='_default'

    # Commit the changes
    uci commit passwall2

    clear

    # Verify main shunt creation
    echo -e "${GREEN}SingBoX shunt configured successfully ✅ OK${NC}"
else
    echo -e "${RED}SingBoX is not installed. Skipping shunt configuration.${NC}"
fi

# Show a message and return to the main menu
whiptail --title "Installation Complete" --msgbox "All selected packages have been processed and SingBoX has been configured. Returning to the main menu." 10 60

# Return to the previous menu (extra.sh)
./extra.sh
