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
 _______           _______  __   __     __    __            __          
|       \         |       \|  \ |  \   |  \  |  \          |  \         
| ▓▓▓▓▓▓▓\ ______ | ▓▓▓▓▓▓▓\\▓▓_| ▓▓_  | ▓▓  | ▓▓ ______  _| ▓▓_        
| ▓▓__/ ▓▓/      \| ▓▓  | ▓▓  \   ▓▓ \  \▓▓\/  ▓▓/      \|   ▓▓ \       
| ▓▓    ▓▓  ▓▓▓▓▓▓\ ▓▓  | ▓▓ ▓▓\▓▓▓▓▓▓   >▓▓  ▓▓|  ▓▓▓▓▓▓\\▓▓▓▓▓▓       
| ▓▓▓▓▓▓▓| ▓▓    ▓▓ ▓▓  | ▓▓ ▓▓ | ▓▓ __ /  ▓▓▓▓\| ▓▓   \▓▓ | ▓▓ __      
| ▓▓     | ▓▓▓▓▓▓▓▓ ▓▓__/ ▓▓ ▓▓ | ▓▓|  \  ▓▓ \▓▓\ ▓▓       | ▓▓|  \     
| ▓▓      \▓▓     \ ▓▓    ▓▓ ▓▓  \▓▓  ▓▓ ▓▓  | ▓▓ ▓▓        \▓▓  ▓▓     
 \▓▓       \▓▓▓▓▓▓▓\▓▓▓▓▓▓▓ \▓▓   \▓▓▓▓ \▓▓   \▓▓\▓▓         \▓▓▓▓      
                                                 

                    P a s s W a l l  E  X  T  R  A   T  O  O  L  S  
${NC}"

# Update package lists
echo -e "${BLUE}Updating package lists...${NC}"
opkg update

# List of packages to install
packages="sing-box haproxy v2ray-core luci-app-v2raya luci-app-openvpn softethervpn5-client fontconfig luci-app-wol hysteria"

# Initialize installation results variable
install_results=""

# Install each package if it's not already installed
for package in $packages; do
    if ! opkg list-installed | grep -q "^${package} "; then
        echo -e "${YELLOW}Installing ${package}...${NC}"
        opkg install "${package}"

        # Check installation success and store result
        if opkg list-installed | grep -q "^${package} "; then
            install_results="${install_results}${GREEN}${package} installed successfully ✅ OK${NC}\n"
        else
            install_results="${install_results}${RED}${package} installation failed ❌ FAILED${NC}\n"
        fi
    else
        echo -e "${CYAN}${package} is already installed. Skipping...${NC}"
        install_results="${install_results}${CYAN}${package} is already installed. Skipping...${NC}\n"
    fi
done

# Define and configure the main shunt
echo -e "${YELLOW}Configuring SingBoX shunt...${NC}"
uci set passwall2.MainShunt=nodes
uci set passwall2.MainShunt.remarks='SingBoX-Shunt'
uci set passwall2.MainShunt.type='Sing-Box'
uci set passwall2.MainShunt.protocol='_shunt'
uci set passwall2.MainShunt.Direct='_direct'
uci set passwall2.MainShunt.DirectGame='_default'

# Commit the changes
uci commit passwall2

# Verify main shunt creation
echo -e "${BLUE}Verifying SingBoX shunt creation...${NC}"
if uci show passwall2.MainShunt | grep -q "remarks='SingBoX-Shunt'"; then
    echo -e "${GREEN}SingBoX shunt configured successfully ✅ OK${NC}"
else
    echo -e "${RED}SingBoX shunt configuration failed ❌ FAILED${NC}"
fi

# Display installation results for each package
echo -e "\n# Verification Results:"
for result in "${install_results[@]}"; do
    echo -e "${result}"
done

# Prompt user for continuation with colored text
read -p "$(echo -e "${GREEN} Enter to continue or press 0 to exit: ${NC}")" user_input

if [[ "$user_input" == "0" ]]; then
    echo -e "${YELLOW}Exiting script...${NC}"
    exit 0
else
    rm -f extra.sh && wget https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/extras/extra.sh && chmod 777 extra.sh && sh extra.sh
fi

# Display the "Made by PeDitX" message
echo -e "${MAGENTA}Made by PeDitX${NC}"
sleep 5  # Wait for 5 seconds before exiting

echo -e "${MAGENTA}All installations and configurations completed.${NC}"
