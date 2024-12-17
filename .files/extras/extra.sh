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
    option=$(whiptail --title "Extra Tools Menu" --menu "Choose an option:" 20 60 10 \
        "1" "Run WiFi settings" \
        "2" "Install Extra tools for passwall for +512mb routers" \
        "3" "Cleanup memory" \
        "4" "Install CloudFlare Warp plus" \
        "5" "Auto Router IP Changer" \
        "6" "Changing Repository to PeDitX-Repository" \
        "0" "Exit" 3>&1 1>&2 2>&3)

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
        0)
            echo -e "${RED}Exiting the program...${NC}"
            break
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            ;;
    esac
done

# Display the "Made by PeDitX" message
echo -e "${MAGENTA}Made by PeDitX${NC}"
sleep 5  # Wait for 5 seconds before exiting
