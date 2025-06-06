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

# Menu loop
while true; do
    echo -e "${CYAN}Please select an option:${NC}"
    echo -e "${RED}1. Run WiFi settings${NC}"
    echo -e "${CYAN}2. Install Extra tools for passwall for +512mb routers${NC}"
    echo -e "${GREEN}3. Cleanup memory${NC}"
    echo -e "${YELLOW}4. Install CloudFlare Warp plus${NC}"
    echo -e "${CYAN}5. Auto Router IP Changer${NC}"
    echo -e "${GREEN}6. Changing Repository to PeDitX-Repository${NC}"
    echo -e "${BLUE}0. Return to main menu${NC}"
    echo -e "${RED}11. Exit${NC}"

    read -p "Your choice: " option

    case $option in
        1)
            echo -e "${GREEN}Running WiFi settings...${NC}"
            rm -f wifi.sh && wget https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/extras/wifi.sh && chmod 777 wifi.sh && sh wifi.sh
            ;;
        2)
            echo -e "${GREEN}Running WiFi settings...${NC}"
            rm -f expass.sh && wget https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/extras/expass.sh && chmod 777 expass.sh && sh expass.sh
            ;;
        3)
            echo -e "${YELLOW}Cleaning up memory...${NC}"
            rm -f /root/*.sh /root/*.pub /root/*.b64
            echo -e "${GREEN}ِYour Memory is Clean...${NC}"
            ;;
        4)
            echo -e "${GREEN}Running WiFi settings...${NC}"
            rm -f warpplus.sh && wget https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/extras/warpplus.sh && chmod 777 warpplus.sh && sh warpplus.sh
            ;;
        5)
            echo -e "${GREEN}Running WiFi settings...${NC}"
            rm -f ip.sh && wget https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/extras/ip.sh && chmod 777 ip.sh && sh ip.sh
            ;;
        6)
            echo -e "${GREEN}Running WiFi settings...${NC}"
            rm -f repo.sh && wget https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/extras/repo.sh && chmod 777 repo.sh && sh repo.sh
            ;;
        0)
            echo -e "${CYAN}Returning to the main menu...${NC}"
            rm -f ezp.sh && wget -qO - https://raw.githubusercontent.com/peditx/EZpasswall/refs/heads/main/ezp.b64 | awk '{print $1}' | base64 -d > ezp.sh && chmod +x ezp.sh && sh ezp.sh
            ;;
        11)
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

