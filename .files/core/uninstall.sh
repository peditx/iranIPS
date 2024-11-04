#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Clear the terminal
clear

# Display the banner in magenta
echo -e "${MAGENTA}
 _______           _______  __   __     __    __            __          
|       \\         |       \\|  \\ |  \\   |  \\  |  \\          |  \\         
| ▓▓▓▓▓▓▓\\ ______ | ▓▓▓▓▓▓▓\\\\▓▓_| ▓▓_  | ▓▓  | ▓▓ ______  _| ▓▓_        
| ▓▓__/ ▓▓/      \\| ▓▓  | ▓▓  \\   ▓▓ \\  \\▓▓\\/  ▓▓/      \\|   ▓▓ \\       
| ▓▓    ▓▓  ▓▓▓▓▓▓\\ ▓▓  | ▓▓ ▓▓\\▓▓▓▓▓▓   >▓▓  ▓▓|  ▓▓▓▓▓▓\\▓▓▓▓▓▓       
| ▓▓▓▓▓▓▓| ▓▓    ▓▓ ▓▓  | ▓▓ ▓▓ | ▓▓ __ /  ▓▓▓▓\\| ▓▓   \\▓▓ | ▓▓ __      
| ▓▓     | ▓▓▓▓▓▓▓▓ ▓▓__/ ▓▓ ▓▓ | ▓▓|  \\  ▓▓ \\▓▓\\ ▓▓       | ▓▓|  \\     
| ▓▓      \\▓▓     \\ ▓▓    ▓▓ ▓▓  \\▓▓  ▓▓ ▓▓  | ▓▓ ▓▓        \\▓▓  ▓▓     
 \\▓▓       \\▓▓▓▓▓▓▓\\▓▓▓▓▓▓▓ \\▓▓   \\▓▓▓▓ \\▓▓   \\▓▓\\▓▓         \\▓▓▓▓      
                                                 
                                               Uninstall   T  O  O  L  S 
${NC}"

# Uninstall watchcat
echo -e "${BLUE}Uninstalling watchcat...${NC}"
if opkg list-installed | grep -q "^watchcat"; then
  opkg remove watchcat
  echo -e "${GREEN}watchcat has been removed successfully.${NC}"
else
  echo -e "${YELLOW}watchcat is not installed.${NC}"
fi

# Uninstall v2raya
echo -e "${BLUE}Uninstalling v2rayA...${NC}"
if opkg list-installed | grep -q "^luci-app-v2raya"; then
  opkg remove luci-app-v2raya
  echo -e "${GREEN}watchcat has been removed successfully.${NC}"
else
  echo -e "${YELLOW}watchcat is not installed.${NC}"
fi

# Uninstall wol
echo -e "${BLUE}Uninstalling Wol...${NC}"
if opkg list-installed | grep -q "^luci-app-wol"; then
  opkg remove luci-app-wol
  echo -e "${GREEN}watchcat has been removed successfully.${NC}"
else
  echo -e "${YELLOW}watchcat is not installed.${NC}"
fi

# Uninstall luci-app-watchcat
echo -e "${BLUE}Uninstalling luci-app-watchcat...${NC}"
if opkg list-installed | grep -q "^luci-app-watchcat"; then
  opkg remove luci-app-watchcat
  echo -e "${GREEN}luci-app-watchcat has been removed successfully.${NC}"
else
  echo -e "${YELLOW}luci-app-watchcat is not installed.${NC}"
fi

# Uninstall passwall if installed
echo -e "${BLUE}Uninstalling passwall...${NC}"
if opkg list-installed | grep -q "^luci-app-passwall"; then
  opkg remove luci-app-passwall
  echo -e "${GREEN}passwall has been removed successfully.${NC}"
else
  echo -e "${YELLOW}passwall is not installed.${NC}"
fi

# Uninstall passwall2 if installed
echo -e "${BLUE}Uninstalling passwall2...${NC}"
if opkg list-installed | grep -q "^luci-app-passwall2"; then
  opkg remove luci-app-passwall2
  echo -e "${GREEN}passwall2 has been removed successfully.${NC}"
else
  echo -e "${YELLOW}passwall2 is not installed.${NC}"
fi

# Remove warp executable and init script
echo -e "${BLUE}Removing warp files...${NC}"
if [ -f /usr/bin/warp ]; then
  rm /usr/bin/warp
  echo -e "${GREEN}Removed /usr/bin/warp.${NC}"
else
  echo -e "${YELLOW}/usr/bin/warp does not exist. Skipping.${NC}"
fi

if [ -f /etc/init.d/warp ]; then
  rm /etc/init.d/warp
  echo -e "${GREEN}Removed /etc/init.d/warp.${NC}"
else
  echo -e "${YELLOW}/etc/init.d/warp does not exist. Skipping.${NC}"
fi

# Remove Passwall or Passwall2 configuration
echo -e "${BLUE}Removing Passwall configuration...${NC}"
if uci show passwall > /dev/null 2>&1; then
  uci delete passwall.WarpPlus
  uci commit passwall
  echo -e "${GREEN}Passwall configuration reset successfully.${NC}"
elif uci show passwall2 > /dev/null 2>&1; then
  uci delete passwall2.WarpPlus
  uci commit passwall2
  echo -e "${GREEN}Passwall2 configuration reset successfully.${NC}"
else
  echo -e "${YELLOW}Neither Passwall nor Passwall2 configuration found.${NC}"
fi

echo -e "${CYAN}Cleanup completed.${NC}"
