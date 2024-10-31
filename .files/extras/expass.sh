
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

# Array of packages to install
packages=(
    "sing-box"
    "haproxy"
    "v2ray-core"
    "luci-app-v2raya"
    "luci-app-openvpn"
    "softethervpn5-client"
    "fontconfig"
    "luci-app-wol"  # Adding luci-app-wol to the installation list
)

# Install each package if it's not already installed
for package in "${packages[@]}"; do
    if ! opkg list-installed | grep -q "^${package} "; then
        echo -e "${YELLOW}Installing ${package}...${NC}"
        opkg install "${package}"
    else
        echo -e "${CYAN}${package} is already installed. Skipping...${NC}"
    fi
done

# Define and configure the singbox shunt
echo -e "${YELLOW}Configuring singbox shunt...${NC}"
uci set passwall2.singshunt=shunt_rules
uci set passwall2.singshunt.network='tcp,udp'
uci set passwall2.singshunt.remarks='singshunt'
uci set passwall2.singshunt.ip_list='geoip:ir
0.0.0.0/8
10.0.0.0/8
100.64.0.0/10
127.0.0.0/8
169.254.0.0/16
172.16.0.0/12
192.0.0.0/24
192.0.2.0/24
192.88.99.0/24
192.168.0.0/16
198.19.0.0/16
198.51.100.0/24
203.0.113.0/24
224.0.0.0/4
240.0.0.0/4
255.255.255.255/32
::/128
::1/128
::ffff:0:0:0/96
64:ff9b::/96
100::/64
2001::/32
2001:20::/28
2001:db8::/32
2002::/16
fc00::/7
fe80::/10
ff00::/8'
uci set passwall2.singshunt.domain_list='regexp:^.+\.ir$
geosite:category-ir
kifpool.me'

# Commit the changes
uci commit passwall2

# Verification of installations and configurations
echo -e "\n${MAGENTA}Verification Results:${NC}"

# Verify each package installation separately
if opkg list-installed | grep -q "^sing-box "; then
    echo -e "${GREEN}sing-box installed successfully ✅ OK${NC}"
else
    echo -e "${RED}sing-box installation failed ❌ FAILED${NC}"
fi

if opkg list-installed | grep -q "^haproxy "; then
    echo -e "${GREEN}haproxy installed successfully ✅ OK${NC}"
else
    echo -e "${RED}haproxy installation failed ❌ FAILED${NC}"
fi

if opkg list-installed | grep -q "^v2ray-core "; then
    echo -e "${GREEN}v2ray-core installed successfully ✅ OK${NC}"
else
    echo -e "${RED}v2ray-core installation failed ❌ FAILED${NC}"
fi

if opkg list-installed | grep -q "^luci-app-v2raya "; then
    echo -e "${GREEN}luci-app-v2raya installed successfully ✅ OK${NC}"
else
    echo -e "${RED}luci-app-v2raya installation failed ❌ FAILED${NC}"
fi

if opkg list-installed | grep -q "^luci-app-openvpn "; then
    echo -e "${GREEN}luci-app-openvpn installed successfully ✅ OK${NC}"
else
    echo -e "${RED}luci-app-openvpn installation failed ❌ FAILED${NC}"
fi

if opkg list-installed | grep -q "^softethervpn5-client "; then
    echo -e "${GREEN}softethervpn5-client installed successfully ✅ OK${NC}"
else
    echo -e "${RED}softethervpn5-client installation failed ❌ FAILED${NC}"
fi

if opkg list-installed | grep -q "^fontconfig "; then
    echo -e "${GREEN}fontconfig installed successfully ✅ OK${NC}"
else
    echo -e "${RED}fontconfig installation failed ❌ FAILED${NC}"
fi

if opkg list-installed | grep -q "^luci-app-wol "; then
    echo -e "${GREEN}luci-app-wol installed successfully ✅ OK${NC}"
else
    echo -e "${RED}luci-app-wol installation failed ❌ FAILED${NC}"
fi

# Verify shunt creation
echo -e "${BLUE}Verifying singbox shunt creation...${NC}"
if uci show passwall2.singshunt >/dev/null 2>&1; then
    echo -e "${GREEN}singbox shunt configured successfully with remarks 'singshunt' ✅ OK${NC}"
else
    echo -e "${RED}singbox shunt configuration failed ❌ FAILED${NC}"
fi

# Display the "Made by PeDitX" message
echo -e "${MAGENTA}Made by PeDitX${NC}"
sleep 5  # Wait for 5 seconds before exiting

echo -e "${MAGENTA}All installations and configurations completed.${NC}"
