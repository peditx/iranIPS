#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color


#Download resize Script
curl -O https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/resize.sh

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
                                                
                                                X86  T  O  O  L  S
${NC}"

# Welcome message
echo -e "${GREEN}Welcome to the installer!${NC}"
echo ""

# Check the system OS
OS_NAME=$(uname -o)

# Show warning message if the OS is OpenWRT or ImmortalWRT
echo -e "${RED} If your operating system is OpenWRT or ImmortalWRT, this section may not function properly and could potentially harm your device. It is advisable to choose option 0 to return to the main menu. ${NC}"
    echo ""

# Prompt user to continue
read -p "Press Enter to continue"

# Show options in yellow
echo -e "${YELLOW}Please select your OS you need to install:${NC}"
echo -e "${RED}1-${NC} ${MAGENTA}PeDitXrt${NC}"
echo -e "${RED}2-${NC} ${CYAN}MikroTik${NC}"
echo -e "${RED}3-${NC} ${GREEN}OpenWRT${NC}"
echo -e "${RED}4-${NC} ${YELLOW}ImmortalWRT${NC}"
echo -e "${RED}5-${NC} ${BLUE}Custom Link${NC}"
echo -e "${RED}0-${NC} Back to main Menu${NC}"
echo ""

# Loop until a valid choice is made
while true; do
    read -p "Enter your choice (0-5): " choice

    # Declare an associative array for script names and download URLs
    declare -A scripts
    scripts[1]="PeDitXrt.sh https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/PeDitXrt.sh"
    scripts[2]="Mikrotik.sh https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/Mikrotik.sh"
    scripts[3]="Openwrt.sh https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/Openwrt.sh"
    scripts[4]="Immortalwrt.sh https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/Immortalwrt.sh"
    scripts[5]="Custom.sh https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/Custom.sh"

    # Check if the choice is valid and handle the corresponding action
    if [[ "$choice" =~ ^[0-5]$ ]]; then
        if [[ "$choice" -eq 0 ]]; then
            echo -e "${CYAN}Running cleanup and downloading ezp.sh...${NC}"
            rm -f ezp.sh && wget https://github.com/peditx/EZpasswall/raw/refs/heads/main/ezp.sh && chmod 777 ezp.sh && sh ezp.sh
            break
        else
            script_info=${scripts[$choice]}
            script_name=$(echo $script_info | cut -d ' ' -f 1)
            script_url=$(echo $script_info | cut -d ' ' -f 2)

            echo -e "${CYAN}Downloading $script_name from $script_url...${NC}"

            # Download the script using curl
            curl -O "$script_url"

            # Check if the script was downloaded successfully
            if [[ -f $script_name ]]; then
                chmod +x "$script_name"
                ./"$script_name"
            else
                echo -e "${RED}Error: $script_name not found after download.${NC}"
            fi
            break
        fi
    else
        echo -e "${MAGENTA}Invalid choice. Please enter a number between 0 and 5.${NC}"
    fi
done

exit 0
