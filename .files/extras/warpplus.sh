#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo "Running as root..."
sleep 2
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
                                                 

                                W  A  R  P  P  L  U  S  on Passwall   
${NC}"

# Check for root user
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root. Exiting...${NC}"
    exit 1
fi

echo -e "${GREEN}Running as root...${NC}"
sleep 2
clear

# Detect system architecture
ARCH=$(uname -m)
if [[ $ARCH == "x86_64" ]]; then
    WARP_URL="https://github.com/bepass-org/warp-plus/releases/download/linux-amd64/warp-plus_linux-amd64.zip"
elif [[ $ARCH == "aarch64" ]]; then
    WARP_URL="https://github.com/bepass-org/warp-plus/releases/download/linux-arm64/warp-plus_linux-arm64.zip"
else
    echo -e "${RED}System architecture not supported.${NC}"
    exit 1
fi

# Download and extract warp
cd /tmp || exit
echo -e "${CYAN}Downloading Warp...${NC}"
wget -O warp.zip "$WARP_URL"
if [[ $? -ne 0 ]]; then
    echo -e "${RED}Failed to download Warp. Exiting...${NC}"
    exit 1
fi

echo -e "${CYAN}Extracting Warp...${NC}"
unzip -o warp.zip
if [[ $? -ne 0 ]]; then
    echo -e "${RED}Failed to extract Warp. Exiting...${NC}"
    exit 1
fi

# Rename and move the warp executable to /usr/bin
mv warp-plus warp
cp warp /usr/bin/
chmod +x /usr/bin/warp

# Create warp init script in /etc/init.d
cat << 'EOF' > /etc/init.d/warp
#!/bin/sh /etc/rc.common

START=91
USE_PROCD=1
PROG=/usr/bin/warp

start_service() {
  args=""
  args="$args -b 127.0.0.1:8086 --scan"
  procd_open_instance
  procd_set_param command $PROG $args
  procd_set_param stdout 1
  procd_set_param stderr 1
  procd_set_param respawn
  procd_close_instance
}
EOF

# Set permissions for init.d script
chmod 755 /etc/init.d/warp

# Enable and start warp service
echo -e "${GREEN}Enabling and starting Warp service...${NC}"
service warp enable
service warp start

# Check if Passwall 2 is installed
if opkg list-installed | grep -q passwall; then
    echo -e "${GREEN}Passwall 2 is installed. Proceeding with configuration...${NC}"

    # Add Warp-plus node and MainShunt settings to Passwall 2
    uci batch <<EOF
set passwall2.@nodes[-1]=node
set passwall2.@nodes[-1].type='Socks'
set passwall2.@nodes[-1].core='Xray'
set passwall2.@nodes[-1].address='127.0.0.1'
set passwall2.@nodes[-1].port='8086'
set passwall2.@nodes[-1].remarks='Warp-plus'
set passwall2.MainShunt.Direct='_direct'
set passwall2.MainShunt.DirectGame='_default'
EOF

    # Commit settings and restart Passwall 2
    uci commit passwall2

    # Restart Passwall service
    if [ -f /etc/init.d/passwall2 ]; then
        echo -e "${GREEN}Restarting Passwall 2...${NC}"
        /etc/init.d/passwall2 restart
    else
        echo -e "${RED}Passwall 2 init script not found. Please check the installation.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Warp-plus node and MainShunt settings added successfully, and Passwall 2 restarted.${NC}"
else
    echo -e "${RED}Passwall 2 is not installed. Please install it before proceeding.${NC}"
    exit 1
fi

echo -e "${YELLOW}** Installation Completed ** ${ENDCOLOR}"
echo -e "${MAGENTA} Made By : PeDitX ${ENDCOLOR}"
sleep 5
