#!/bin/sh

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
                                                 
                                    E  X  T  R  A   T  O  O  L  S 
${NC}"

# Display IP configuration menu
while true; do
    echo
    echo -e "${CYAN}Select IP configuration:${NC}"
    echo "1 - Set IP to 10.1.1.1"
    echo "2 - Set IP to 11.1.1.1"
    echo "3 - Set IP to 192.168.0.1"
    echo "4 - Don't change IP"
    echo "5 - Custom IP address"
    echo "0 - Back to Main menu"
    echo -n "Enter your choice: "
    read -r choice

    case $choice in
        1)
            uci set network.lan.ipaddr='10.1.1.1'
            uci commit network
            echo -e "${GREEN}IP set to 10.1.1.1${NC}"
            ;;
        2)
            uci set network.lan.ipaddr='11.1.1.1'
            uci commit network
            echo -e "${GREEN}IP set to 11.1.1.1${NC}"
            ;;
        3)
            uci set network.lan.ipaddr='192.168.0.1'
            uci commit network
            echo -e "${GREEN}IP set to 192.168.0.1${NC}"
            ;;
        4)
            echo -e "${YELLOW}IP not changed${NC}"
            ;;
        5)
            echo -n "Enter custom IP address: "
            read -r custom_ip
            uci set network.lan.ipaddr="$custom_ip"
            uci commit network
            echo -e "${GREEN}Custom IP set to $custom_ip${NC}"
            ;;
        0)
            echo -e "${BLUE}Returning to main menu...${NC}"
            extra.sh
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice, please try again.${NC}"
            ;;
    esac

    echo -e "${CYAN}Restarting network to apply changes...${NC}"
    /etc/init.d/network restart

    echo -e "${BLUE}Returning to main menu...${NC}"
    extra.sh
    exit 0
done
