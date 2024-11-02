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

# Check if Passwall or Passwall2 is installed
if service passwall2 status > /dev/null 2>&1; then
    # Passwall2 is installed
    uci set passwall2.WarpPlus=nodes
    uci set passwall2.WarpPlus.remarks='Warp-Plus'
    uci set passwall2.WarpPlus.type='Xray'
    uci set passwall2.WarpPlus.protocol='socks'
    uci set passwall2.WarpPlus.server='127.0.0.1'
    uci set passwall2.WarpPlus.port='8086'
    uci set passwall2.WarpPlus.address='127.0.0.1'
    uci set passwall2.WarpPlus.tls='0'
    uci set passwall2.WarpPlus.transport='tcp'
    uci set passwall2.WarpPlus.tcp_guise='none'
    uci set passwall2.WarpPlus.tcpMptcp='0'
    uci set passwall2.WarpPlus.tcpNoDelay='0'

    uci commit passwall2
    echo -e "${GREEN}Passwall2 configuration updated successfully.${NC}"
elif service passwall status > /dev/null 2>&1; then
    # Passwall is installed
    uci set passwall.WarpPlus=nodes
    uci set passwall.WarpPlus.remarks='Warp-Plus'
    uci set passwall.WarpPlus.type='Xray'
    uci set passwall.WarpPlus.protocol='socks'
    uci set passwall.WarpPlus.server='127.0.0.1'
    uci set passwall.WarpPlus.port='8086'
    uci set passwall.WarpPlus.address='127.0.0.1'
    uci set passwall.WarpPlus.tls='0'
    uci set passwall.WarpPlus.transport='tcp'
    uci set passwall.WarpPlus.tcp_guise='none'
    uci set passwall.WarpPlus.tcpMptcp='0'
    uci set passwall.WarpPlus.tcpNoDelay='0'

    uci commit passwall
    echo -e "${GREEN}Passwall configuration updated successfully.${NC}"
else
    echo -e "${RED}Neither Passwall nor Passwall2 is installed. Skipping configuration.${NC}"
fi

echo -e "${YELLOW}** Installation Completed ** ${NC}"
echo -e "${MAGENTA} Made By : PeDitX ${NC}"
sleep 5
