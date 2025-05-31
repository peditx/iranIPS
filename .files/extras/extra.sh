#!/bin/sh

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Clear the terminal
clear

# Menu loop
while true; do
    option=$(whiptail --title "Extra Tools Menu" --menu "Choose an option:" 20 60 12 \
        "1" "Run WiFi settings" \
        "2" "Install Extra tools for passwall for +512mb routers" \
        "3" "Cleanup memory" \
        "4" "Install CloudFlare Warp plus" \
        "5" "Auto Router IP Changer" \
        "6" "Changing Repository to PeDitX-Repository" \
        "7" "Install PeDitX OS SSHPlus" \
        "8" "Install air-cast by PeDitX" \
        "9" "Ez Wake On Lan by PeDitX" 3>&1 1>&2 2>&3)

    # If CANCEL is pressed
    if [ $? -ne 0 ]; then
        sh setup.sh
        exit
    fi

    case $option in
        1)
            echo -e "${GREEN}Running WiFi settings...${NC}"
            rm -f wifi.sh && wget https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/extras/wifi.sh && chmod 777 wifi.sh && sh wifi.sh
            ;;
        2)
            echo -e "${GREEN}Installing Extra tools...${NC}"
            rm -f expass.sh && wget https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/extras/expass.sh && chmod 777 expass.sh && sh expass.sh
            ;;
        3)
            echo -e "${YELLOW}Cleaning up memory...${NC}"
            rm -f /root/*.sh /root/*.pub /root/*.b64
            echo -e "${GREEN}Your Memory is Clean...${NC}"
            ;;
        4)
            echo -e "${GREEN}Installing CloudFlare Warp plus...${NC}"
            rm -f warpplus.sh && wget https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/extras/warpplus.sh && chmod 777 warpplus.sh && sh warpplus.sh
            ;;
        5)
            echo -e "${GREEN}Running Auto Router IP Changer...${NC}"
            rm -f ip.sh && wget https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/extras/ip.sh && chmod 777 ip.sh && sh ip.sh
            ;;
        6)
            echo -e "${GREEN}Changing Repository to PeDitX-Repository...${NC}"
            rm -f repo.sh && wget https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/extras/repo.sh && chmod 777 repo.sh && sh repo.sh
            ;;
        7)
            echo -e "${GREEN}Installing PeDitX OS SSHPlus...${NC}"
            rm -f install_sshplus.sh && wget https://raw.githubusercontent.com/peditx/SshPlus/refs/heads/main/Files/install_sshplus.sh && chmod +x install_sshplus.sh && sh install_sshplus.sh
            ;;
        8)
            echo -e "${GREEN}Installing air-cast by PeDitX...${NC}"
            rm -f *.sh && wget https://raw.githubusercontent.com/peditx/aircast-openwrt/refs/heads/main/aircast_install.sh && sh aircast_install.sh
            ;;
        9)
            # Display educational message
            whiptail --title "Ez Wake On Lan by PeDitX" --msgbox "To turn on a device from the list:\n\n1. Use the format: http://routeraddress/wol/pc-name.html\n\n2. You can create shortcuts:\n   - Siri/Google shortcuts\n   - Home screen shortcuts\n\nPress OK to install the tool" 15 60
            
            echo -e "${GREEN}Running Ez Wake On Lan by PeDitX...${NC}"
            rm -f wol.sh && wget https://raw.githubusercontent.com/peditx/pcpowercontrol-openwrrt/refs/heads/main/wol.sh && chmod +x wol.sh && sh wol.sh
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            ;;
    esac
done

# Display the "Made by PeDitX" message
echo -e "${MAGENTA}Made by PeDitX${NC}"
sleep 5  # Wait for 5 seconds before exiting
