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

# Determine system architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        WARP_URL="https://github.com/bepass-org/warp-plus/releases/download/v1.2.3/warp-plus_linux-amd64.zip"
        ;;
    aarch64)
        WARP_URL="https://github.com/bepass-org/warp-plus/releases/download/v1.2.3/warp-plus_linux-arm64.zip"
        ;;
    armv7l)
        WARP_URL="https://github.com/bepass-org/warp-plus/releases/download/v1.2.3/warp-plus_linux-arm7.zip"
        ;;
    mips)
        WARP_URL="https://github.com/bepass-org/warp-plus/releases/download/v1.2.3/warp-plus_linux-mips.zip"
        ;;
    mips64)
        WARP_URL="https://github.com/bepass-org/warp-plus/releases/download/v1.2.3/warp-plus_linux-mips64.zip"
        ;;
    mips64le)
        WARP_URL="https://github.com/bepass-org/warp-plus/releases/download/v1.2.3/warp-plus_linux-mips64le.zip"
        ;;
    riscv64)
        WARP_URL="https://github.com/bepass-org/warp-plus/releases/download/v1.2.3/warp-plus_linux-riscv64.zip"
        ;;
    *)
        echo -e "${RED}System architecture not supported.${NC}"
        exit 1
        ;;
esac

# Download and extract warp file
cd /tmp || exit
wget -O warp.zip "$WARP_URL"
unzip warp.zip

# Rename and copy the warp executable to /usr/bin
mv warp-plus warp
cp warp /usr/bin/
chmod +x /usr/bin/warp

# Create the init script for warp in /etc/init.d
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

# Set permissions for the init.d script
chmod 755 /etc/init.d/warp

# Enable and start the warp service
service warp enable
service warp start

# Passwall configuration
if service passwall status > /dev/null 2>&1; then
    # Check if passwall settings exist
    uci add passwall.Server
    uci set passwall.Server.@server[-1].type='socks'
    uci set passwall.Server.@server[-1].server='127.0.0.1'
    uci set passwall.Server.@server[-1].port='8086'
    uci set passwall.Server.@server[-1].remarks='Warp-plus'
    uci commit passwall
    echo "Passwall configuration updated successfully."
elif service passwall2 status > /dev/null 2>&1; then
    # Check if passwall2 settings exist
    uci add passwall2.Server
    uci set passwall2.Server.@server[-1].type='socks'
    uci set passwall2.Server.@server[-1].server='127.0.0.1'
    uci set passwall2.Server.@server[-1].port='8086'
    uci set passwall2.Server.@server[-1].remarks='Warp-plus'
    uci set passwall2.MainShunt.Direct='_direct'
    uci set passwall2.MainShunt.DirectGame='_default'
    uci commit passwall2
    echo "Passwall2 configuration updated successfully."
else
    echo "Neither Passwall nor Passwall2 is installed. Skipping configuration."
fi

# Final messages
echo -e "${YELLOW}** Installation Completed ** ${NC}"
echo -e "${MAGENTA} Made By : PeDitX ${NC}"
sleep 5
