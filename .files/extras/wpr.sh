#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

echo "Running as root..."
sleep 2
clear

# Display the banner in magenta
echo -e "${MAGENTA}
 ______      _____   _      _    _     _____       
(_____ \    (____ \ (_)_   \ \  / /   / ___ \      
 _____) )___ _   \ \ _| |_  \ \/ /   | |   | | ___ 
|  ____/ _  ) |   | | |  _)  )  (    | |   | |/___)
| |   ( (/ /| |__/ /| | |__ / /\ \   | |___| |___ |
|_|    \____)_____/ |_|\___)_/  \_\   \_____/(___/ 
                                                   
                       W  A  R  P  P  L  U  S  on Passwall   
${NC}"

# Stop and disable the warp service
echo -e "${YELLOW}Stopping and disabling the warp service...${NC}"
service warp stop
service warp disable

# Remove the warp executable and init script
echo -e "${YELLOW}Removing warp executable and init script...${NC}"
rm -f /usr/bin/warp
rm -f /etc/init.d/warp

# Remove configuration from Passwall or Passwall2
echo -e "${YELLOW}Removing WarpPlus configuration from Passwall/Passwall2...${NC}"
if service passwall2 status > /dev/null 2>&1; then
    uci delete passwall2.WarpPlus
    uci commit passwall2
    echo -e "${GREEN}Passwall2 configuration removed.${NC}"
elif service passwall status > /dev/null 2>&1; then
    uci delete passwall.WarpPlus
    uci commit passwall
    echo -e "${GREEN}Passwall configuration removed.${NC}"
else
    echo -e "${RED}Neither Passwall nor Passwall2 is installed. Skipping configuration removal.${NC}"
fi

# Uninstall watchcat and luci-app-watchcat
echo -e "${YELLOW}Uninstalling watchcat and luci-app-watchcat...${NC}"
opkg remove watchcat
opkg remove luci-app-watchcat

echo -e "${YELLOW}** Uninstallation Completed ** ${NC}"
echo -e "${MAGENTA} Made By : PeDitX ${NC}"
sleep 5
