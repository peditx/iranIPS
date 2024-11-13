#!/bin/bash

# Clear the screen
clear

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Header
echo -e "${GREEN}
_______           _______  __   __     __    __            __          
|       \         |       \|  \ |  \   |  \  |  \          |  \         
| ▓▓▓▓▓▓▓\ ______ | ▓▓▓▓▓▓▓\\▓▓_| ▓▓_  | ▓▓  | ▓▓ ______  _| ▓▓_        
| ▓▓__/ ▓▓/      \| ▓▓  | ▓▓  \   ▓▓ \  \▓▓\/  ▓▓/      \|   ▓▓ \       
| ▓▓    ▓▓  ▓▓▓▓▓▓\ ▓▓  | ▓▓ ▓▓\▓▓▓▓▓▓   >▓▓  ▓▓|  ▓▓▓▓▓▓\\▓▓▓▓▓▓       
| ▓▓▓▓▓▓▓| ▓▓    ▓▓ ▓▓  | ▓▓ ▓▓ | ▓▓ __ /  ▓▓▓▓\| ▓▓   \▓▓ | ▓▓ __      
| ▓▓     | ▓▓▓▓▓▓▓▓ ▓▓__/ ▓▓ ▓▓ | ▓▓|  \  ▓▓ \▓▓\ ▓▓       | ▓▓|  \     
| ▓▓      \▓▓     \ ▓▓    ▓▓ ▓▓  \▓▓  ▓▓ ▓▓  | ▓▓ ▓▓        \▓▓  ▓▓     
 \▓▓       \▓▓▓▓▓▓▓\▓▓▓▓▓▓▓ \▓▓   \▓▓▓▓ \▓▓   \▓▓\▓▓         \▓▓▓▓      
                                                    
                                                     For Mr K H A L E G H I by PeDitX${NC}"

# Display warning to the user before proceeding
echo -e "${RED}
WARNING!!
If you are running this code for the first time, it is recommended that you first complete the EZPasswall setup instructions from the GitHub page: https://github.com/peditx/EZpasswall
Without the correct EZPasswall configuration, this script may not work properly!
${NC}"

# Wait for the user to press Enter before continuing
read -p "Press Enter to continue..." 

# System Information
EPOL=`cat /tmp/sysinfo/model`
echo -e "${CYAN} - Model : $EPOL${NC}"
echo -e "${CYAN} - System Ver : $DISTRIB_RELEASE${NC}"
echo -e "${CYAN} - System Arch : $DISTRIB_ARCH${NC}"

# Write to banner
echo "                _                  _
    (_)       | |_               | |_               
          __  | ,_)  ___     __  | ,_)   ___    _   
    | | /'__`\| |  /' _ `\ /'__`\| |   /'___) /'_`\ 
    | |(  ___/| |_ | ( ) |(  ___/| |_ ( (___ ( (_) )
 _  | |`\____)`\__)(_) (_)`\____)`\__)`\____)`\___/'
( )_| |                                             
`\___/            
                                      
                        J  E  T  N  E  T  C  O  
 ------------------------------------------------------------------
 https://jetnetco.com
 tel: 021-33113186
 powered by : PeDitXrt
 ------------------------------------------------------------------" > /etc/banner

# Verify banner update
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Banner updated successfully ✅ OK${NC}"
else
    echo -e "${RED}Banner update failed ❌ FAILED${NC}"
fi

# Change hostname to Jetnetco
uci set system.@system[0].hostname='Jetnetco'
uci commit system

# Restart system to apply hostname changes
/etc/init.d/system restart

# Verify hostname change
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Hostname changed to Jetnetco successfully ✅ OK${NC}"
else
    echo -e "${RED}Hostname change failed ❌ FAILED${NC}"
fi

# Wi-Fi 2.4GHz Configuration
echo -e "${YELLOW}Configuring Wi-Fi 2.4GHz...${NC}"

# Enable Wi-Fi 2.4GHz
uci set wireless.radio0.disabled='0'
uci commit wireless

# Change SSID to jetnetco-wifi and set password
uci set wireless.default_radio0.ssid='jetnetco-wifi'
uci set wireless.default_radio0.key='1234567890'
uci commit wireless

# Restart Wi-Fi
wifi

# Verify Wi-Fi configuration
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Wi-Fi 2.4GHz configured successfully ✅ OK${NC}"
else
    echo -e "${RED}Wi-Fi 2.4GHz configuration failed ❌ FAILED${NC}"
fi

# Verification Results
echo -e "\nVerification Results:"

if opkg list-installed | grep -q "luci-theme-argon"; then
    echo -e "${GREEN}Theme installed successfully ✅ OK${NC}"
else
    echo -e "${RED}Theme installation failed ❌ FAILED${NC}"
fi

if opkg list-installed | grep -q "luci-app-argon-config"; then
    echo -e "${GREEN}Config installed successfully ✅ OK${NC}"
else
    echo -e "${RED}Config installation failed ❌ FAILED${NC}"
fi

if [ -f "$svg_path" ]; then
    echo -e "${GREEN}SVG image replaced successfully ✅ OK${NC}"
else
    echo -e "${RED}SVG image replacement failed ❌ FAILED${NC}"
fi

if [ -f "$bg_path" ]; then
    echo -e "${GREEN}Background image replaced successfully ✅ OK${NC}"
else
    echo -e "${RED}Background image replacement failed ❌ FAILED${NC}"
fi

if [ -f "$favicon_path" ]; then
    echo -e "${GREEN}Favicon replaced successfully ✅ OK${NC}"
else
    echo -e "${RED}Favicon replacement failed ❌ FAILED${NC}"
fi

# 5-second pause before showing final message
sleep 5

# Final message
echo -e "${MAGENTA}Made by PeDitX${NC}"

# 5-second pause for the "Made by PeDitX" message
sleep 5
