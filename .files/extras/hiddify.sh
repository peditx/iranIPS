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
 _______             _______   __    __      __    __         ______    ______  
|       \           |       \ |  \  |  \    |  \  |  \       /      \  /      \ 
| $$$$$$$\  ______  | $$$$$$$\ \$$ _| $$_   | $$  | $$      |  $$$$$$\|  $$$$$$\
| $$__/ $$ /      \ | $$  | $$|  \|   $$ \   \$$\/  $$      | $$  | $$| $$___\$$
| $$    $$|  $$$$$$\| $$  | $$| $$ \$$$$$$    >$$  $$       | $$  | $$ \$$    \ 
| $$$$$$$ | $$    $$| $$  | $$| $$  | $$ __  /  $$$$\       | $$  | $$ _\$$$$$$\
| $$      | $$$$$$$$| $$__/ $$| $$  | $$|  \|  $$ \$$\      | $$__/ $$|  \__| $$
| $$       \$$     \| $$    $$| $$   \$$  $$| $$  | $$       \$$    $$ \$$    $$
 \$$        \$$$$$$$ \$$$$$$$  \$$    \$$$$  \$$   \$$        \$$$$$$   \$$$$$$ 
                                                                                
                                                                                
                                                                                                           

                       H  I  D  D  I  F  Y - Client on Passwall    
${NC}"

# Set architecture
ARCHITECTURES=("386" "amd64" "arm64" "armv5" "armv6" "armv7" "mips-hardfloat" "mips-softfloat" "mips64" "mips64el" "mipsel-hardfloat" "mipsel-softfloat" "s390x")

# Define the base URL for the downloads
BASE_URL="https://github.com/hiddify/hiddify-core/releases/download/v3.1.8/"

# Check the system architecture
ARCH=$(uname -m)

# Check if the architecture is in the list of supported architectures
if [[ " ${ARCHITECTURES[@]} " =~ " ${ARCH} " ]]; then
    echo -e "${YELLOW}Downloading HiddifyCli for architecture ${ARCH}...${NC}"
    DOWNLOAD_URL="${BASE_URL}hiddify-cli-linux-${ARCH}.tar.gz"
    
    # Download the appropriate file
    curl -L $DOWNLOAD_URL -o /tmp/hiddify-cli.tar.gz

    # Check if the download was successful
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Download successful.${NC}"
        
        # Extract the downloaded file
        tar -xvzf /tmp/hiddify-cli.tar.gz -C /tmp

        # Move the extracted file to /usr/bin
        mv /tmp/hiddify-cli-linux-* /usr/bin/HiddifyCli
        chmod +x /usr/bin/HiddifyCli

        echo -e "${GREEN}HiddifyCli installed successfully.${NC}"
    else
        echo -e "${RED}Failed to download HiddifyCli.${NC}"
    fi
else
    echo -e "${RED}Architecture ${ARCH} is not supported. Please check the available architectures.${NC}"
fi

# Configure Passwall or Passwall2 if installed
if service passwall2 status > /dev/null 2>&1; then
    # Passwall2 is installed
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
    # Passwall is installed
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
