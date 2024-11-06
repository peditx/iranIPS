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

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "${RED}This script must be run as root. Please use 'sudo'.${NC}"
    exit 1
fi

# Check if wget is installed
if ! command -v wget &> /dev/null; then
    echo "${RED}wget is not installed. Installing it now...${NC}"
    apt update && apt install -y wget
fi

# Download resize Script
wget https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/resize.sh

# Clear the terminal
clear

# Display the banner in magenta
echo "${MAGENTA}
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
echo "${GREEN}Welcome to the installer!${NC}"
echo ""

# Check the system OS
OS_NAME=$(uname -o)

# Show warning message if the OS is OpenWRT or ImmortalWRT
echo "${RED}If your operating system is OpenWRT or ImmortalWRT, this section may not function properly and could potentially harm your device. It is advisable to choose option 0 to return to the main menu.${NC}"
echo ""

# Prompt user to continue
echo "Press Enter to continue"
read -r

# Show options in yellow
echo "${YELLOW}Please select your OS you need to install:${NC}"
echo "${RED}1-${NC} ${MAGENTA}PeDitXrt${NC}"
echo "${RED}2-${NC} ${CYAN}MikroTik${NC}"
echo "${RED}3-${NC} ${GREEN}OpenWRT${NC}"
echo "${RED}4-${NC} ${YELLOW}ImmortalWRT${NC}"
echo "${RED}5-${NC} ${BLUE}Custom Link${NC}"
echo "${RED}0-${NC} Back to main Menu${NC}"
echo ""

# Loop until a valid choice is made
while true; do
    read -p "Enter your choice (0-5): " choice

    # Check if the choice is valid and handle the corresponding action
    case "$choice" in
        0)
            echo "${CYAN}Running cleanup and downloading ezp.sh...${NC}"
            rm -f ezp.sh && wget https://github.com/peditx/EZpasswall/raw/refs/heads/main/ezp.sh && chmod +x ezp.sh && ./ezp.sh
            break
            ;;
        1|2|3|4|5)
            script_info=""
            case "$choice" in
                1) script_info="PeDitXrt.sh https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/PeDitXrt.sh" ;;
                2) script_info="Mikrotik.sh https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/Mikrotik.sh" ;;
                3) script_info="Openwrt.sh https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/Openwrt.sh" ;;
                4) script_info="Immortalwrt.sh https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/Immortalwrt.sh" ;;
                5) script_info="Custom.sh https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/Custom.sh" ;;
            esac

            script_name=$(echo $script_info | cut -d ' ' -f 1)
            script_url=$(echo $script_info | cut -d ' ' -f 2)

            echo "${CYAN}Downloading $script_name from $script_url...${NC}"

            # Download the script using wget
            wget "$script_url" -O "$script_name"

            # Check if the script was downloaded successfully
            if [[ -f $script_name ]]; then
                chmod +x "$script_name"
                ./"$script_name"
            else
                echo "${RED}Error: $script_name not found after download.${NC}"
            fi
            break
            ;;
        *)
            echo "${MAGENTA}Invalid choice. Please enter a number between 0 and 5.${NC}"
            ;;
    esac
done

exit 0
