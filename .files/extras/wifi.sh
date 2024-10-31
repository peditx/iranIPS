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
|       \         |       \|  \ |  \   |  \  |  \          |  \         
| ▓▓▓▓▓▓▓\ ______ | ▓▓▓▓▓▓▓\\▓▓_| ▓▓_  | ▓▓  | ▓▓ ______  _| ▓▓_        
| ▓▓__/ ▓▓/      \| ▓▓  | ▓▓  \   ▓▓ \  \▓▓\/  ▓▓/      \|   ▓▓ \       
| ▓▓    ▓▓  ▓▓▓▓▓▓\ ▓▓  | ▓▓ ▓▓\▓▓▓▓▓▓   >▓▓  ▓▓|  ▓▓▓▓▓▓\\▓▓▓▓▓▓       
| ▓▓▓▓▓▓▓| ▓▓    ▓▓ ▓▓  | ▓▓ ▓▓ | ▓▓ __ /  ▓▓▓▓\| ▓▓   \▓▓ | ▓▓ __      
| ▓▓     | ▓▓▓▓▓▓▓▓ ▓▓__/ ▓▓ ▓▓ | ▓▓|  \  ▓▓ \▓▓\ ▓▓       | ▓▓|  \     
| ▓▓      \▓▓     \ ▓▓    ▓▓ ▓▓  \▓▓  ▓▓ ▓▓  | ▓▓ ▓▓        \▓▓  ▓▓     
 \▓▓       \▓▓▓▓▓▓▓\▓▓▓▓▓▓▓ \▓▓   \▓▓▓▓ \▓▓   \▓▓\▓▓         \▓▓▓▓      
                                                 
                                          W  I  F  I  C  O  N  F  I  G
${NC}"

# Get WiFi name from the user
read -p "${CYAN}Please enter the new WiFi name (SSID): ${NC}" new_ssid

# Get WiFi password from the user
read -p "${CYAN}Please enter the new WiFi password: ${NC}" new_password

# Path to the WiFi configuration file
wifi_config="/etc/config/wireless"

# Update SSID and password
uci set wireless.@wifi-iface[0].ssid="$new_ssid"
uci set wireless.@wifi-iface[0].key="$new_password"

# Set security to WPA/WPA2 PSK (CCMP)
uci set wireless.@wifi-iface[0].encryption='psk2'
uci set wireless.@wifi-iface[0].auth='CCMP'

# Enable the 2.4GHz WiFi
uci set wireless.radio0.disabled='0'

# Commit changes
uci commit wireless

# Restart WiFi services
wifi reload

echo -e "${GREEN}WiFi settings have been successfully updated.${NC}"

# Display "Made By PeDitX" in magenta
echo -e "${MAGENTA}Made By PeDitX${NC}"

# Wait for 5 seconds
sleep 5

# Prompt user for continuation
read -p "${CYAN}Press Enter to continue or press 0 to exit: ${NC}" user_input

if [[ "$user_input" == "0" ]]; then
    echo -e "${YELLOW}Exiting script...${NC}"
    exit 0
else
    rm -f extra.sh && wget https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/extras/extra.sh && chmod 777 extra.sh && sh extra.sh
fi
