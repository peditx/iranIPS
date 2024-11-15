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
                                                 

                            H  I  D  D  I  F  Y - Client on Passwall    
${NC}"

# Check for root permissions
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root.${NC}"
    exit 1
fi

# Define variables
HIDDIFY_BASE_URL="https://github.com/hiddify/hiddify-core/releases/download/latest"
INSTALL_DIR="/usr/bin"
INIT_FILE="/etc/init.d/HiddifyCli"

# Determine architecture
arch=$(uname -m)
case $arch in
    x86_64) ARCHIVE="hiddify-cli-linux-amd64.tar.gz" ;;
    i386 | i686) ARCHIVE="hiddify-cli-linux-386.tar.gz" ;;
    armv5*) ARCHIVE="hiddify-cli-linux-armv5.tar.gz" ;;
    armv6*) ARCHIVE="hiddify-cli-linux-armv6.tar.gz" ;;
    armv7*) ARCHIVE="hiddify-cli-linux-armv7.tar.gz" ;;
    aarch64) ARCHIVE="hiddify-cli-linux-arm64.tar.gz" ;;
    mips) ARCHIVE="hiddify-cli-linux-mips-softfloat.tar.gz" ;;
    mipsel) ARCHIVE="hiddify-cli-linux-mipsel-softfloat.tar.gz" ;;
    mips64) ARCHIVE="hiddify-cli-linux-mips64.tar.gz" ;;
    mips64el) ARCHIVE="hiddify-cli-linux-mips64el.tar.gz" ;;
    s390x) ARCHIVE="hiddify-cli-linux-s390x.tar.gz" ;;
    *) echo -e "${RED}Unsupported architecture: $arch${NC}"; exit 1 ;;
esac

# Download and extract HiddifyCli
echo -e "${YELLOW}Downloading HiddifyCli for architecture $arch...${NC}"
wget -q "$HIDDIFY_BASE_URL/$ARCHIVE" -O /tmp/HiddifyCli.tar.gz
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to download HiddifyCli.${NC}"
    exit 1
fi

echo -e "${YELLOW}Extracting HiddifyCli...${NC}"
tar -xzf /tmp/HiddifyCli.tar.gz -C /tmp
mv /tmp/HiddifyCli "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/HiddifyCli"

# Create init script
echo -e "${YELLOW}Creating init script...${NC}"
cat <<EOF > "$INIT_FILE"
#!/bin/sh /etc/rc.common
START=91
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/HiddifyCli run -c /root/wg.conf
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn
    procd_close_instance
}
EOF

chmod 755 "$INIT_FILE"

# Enable and start the service
echo -e "${YELLOW}Enabling and starting HiddifyCli service...${NC}"
service HiddifyCli enable
service HiddifyCli start

echo -e "${GREEN}HiddifyCli installation completed successfully.${NC}"

# Check if Passwall or Passwall2 is installed
echo -e "${YELLOW}Configuring Passwall or Passwall2...${NC}"
if service passwall2 status > /dev/null 2>&1; then
    uci set passwall2.WarpPlus=nodes
    uci set passwall2.WarpPlus.remarks='Hiddify-Client'
    uci set passwall2.WarpPlus.type='Xray'
    uci set passwall2.WarpPlus.protocol='socks'
    uci set passwall2.WarpPlus.server='127.0.0.1'
    uci set passwall2.WarpPlus.port='2334'
    uci set passwall2.WarpPlus.address='127.0.0.1'
    uci set passwall2.WarpPlus.tls='0'
    uci set passwall2.WarpPlus.transport='tcp'
    uci set passwall2.WarpPlus.tcp_guise='none'
    uci set passwall2.WarpPlus.tcpMptcp='0'
    uci set passwall2.WarpPlus.tcpNoDelay='0'

    uci commit passwall2
    echo -e "${GREEN}Passwall2 configuration updated successfully.${NC}"
elif service passwall status > /dev/null 2>&1; then
    uci set passwall.WarpPlus=nodes
    uci set passwall.WarpPlus.remarks='Hiddify-Client'
    uci set passwall.WarpPlus.type='Xray'
    uci set passwall.WarpPlus.protocol='socks'
    uci set passwall.WarpPlus.server='127.0.0.1'
    uci set passwall.WarpPlus.port='2334'
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
