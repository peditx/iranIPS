#!/bin/bash

# Check if resize.sh exists in the current directory and remove it if it does
if [ -f "resize.sh" ]; then
    printf "Removing existing resize.sh...\n"
    rm -f "resize.sh"
fi

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
if [ "$EUID" -ne 0 ]; then
    printf "${RED}This script must be run as root. Please use 'sudo'.${NC}\n"
    exit 1
fi

# Check if wget is installed
if ! command -v wget &> /dev/null; then
    printf "${RED}wget is not installed. Installing it now...${NC}\n"
    apt update && apt install -y wget
fi

# Download resize Script
wget https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/resize.sh

# Clear the terminal
clear

sudo apt-get update
sudo apt-get install wget curl
clear

echo " First run is ok! lets go next steps ... "
sleep2

clear
# Display the banner in magenta
printf "${MAGENTA}
 _______             _______   __    __      __    __         ______    ______  
|       \           |       \ |  \  |  \    |  \  |  \       /      \  /      \ 
| $$$$$$$\  ______  | $$$$$$$\ \$$ _| $$_   | $$  | $$      |  $$$$$$\|  $$$$$$\
| $$__/ $$ /      \ | $$  | $$|  \|   $$ \   \$$\/  $$      | $$  | $$| $$___\$$
| $$    $$|  $$$$$$\| $$  | $$| $$ \$$$$$$    >$$  $$       | $$  | $$ \$$    \ 
| $$$$$$$ | $$    $$| $$  | $$| $$  | $$ __  /  $$$$\       | $$  | $$ _\$$$$$$\
| $$      | $$$$$$$$| $$__/ $$| $$  | $$|  \|  $$ \$$\      | $$__/ $$|  \__| $$
| $$       \$$     \| $$    $$| $$   \$$  $$| $$  | $$       \$$    $$ \$$    $$
 \$$        \$$$$$$$ \$$$$$$$  \$$    \$$$$  \$$   \$$        \$$$$$$   \$$$$$$ 
                                                                                
                                                                                
                                                                                                
                                                X86  T  O  O  L  S
${NC}\n"

# Welcome message
printf "${GREEN}Welcome to the installer!${NC}\n\n"

# Check the system OS
OS_NAME=$(uname -o)

# Show warning message if the OS is OpenWRT or ImmortalWRT
printf "${RED}If your operating system is OpenWRT or ImmortalWRT, this section may not function properly and could potentially harm your device. It is advisable to choose option 0 to return to the main menu.${NC}\n\n"

# Prompt user to continue
printf "Press Enter to continue"
read -r

# Show options in yellow
printf "${YELLOW}Please select your OS you need to install:${NC}\n"
printf "${RED}1-${NC} ${MAGENTA}PeDitXrt${NC}\n"
printf "${RED}2-${NC} ${CYAN}MikroTik${NC}\n"
printf "${RED}3-${NC} ${GREEN}OpenWRT${NC}\n"
printf "${RED}4-${NC} ${YELLOW}ImmortalWRT${NC}\n"
printf "${RED}5-${NC} ${BLUE}Custom Link${NC}\n"
printf "${RED}0-${NC} Exit${NC}\n\n"

# Loop until a valid choice is made
while true; do
    read -p "Enter your choice (0-5): " choice

    # Check if the choice is valid and handle the corresponding action
    case "$choice" in
        0)
            printf "${CYAN}Exiting the installer...${NC}\n"
            exit 0
            ;;
        1|2|3|4|5)
            script_info=""
            case "$choice" in
                1) script_info="PeDitXrt.sh https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/PeDitXrt.sh" ;;
                2) script_info="Mikrotik.sh https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/Mikrotik.sh" ;;
                3) script_info="Openwrt.sh https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/x86/Openwrt.sh" ;;
                4) script_info="Immortalwrt.sh https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/Immortalwrt.sh" ;;
                5) script_info="Custom.sh https://raw.githubusercontent.com/peditx/easywrt/refs/heads/main/op/Custom.sh" ;;
            esac

            script_name=$(echo $script_info | cut -d ' ' -f 1)
            script_url=$(echo $script_info | cut -d ' ' -f 2)

            printf "${CYAN}Downloading $script_name from $script_url...${NC}\n"

            # Download the script using wget
            wget "$script_url" -O "$script_name"

            # Check if the script was downloaded successfully
            if [ -f "$script_name" ]; then
                chmod +x "$script_name"
                ./"$script_name"
            else
                printf "${RED}Error: $script_name not found after download.${NC}\n"
            fi
            break
            ;;
        *)
            printf "${MAGENTA}Invalid choice. Please enter a number between 0 and 5.${NC}\n"
            ;;
    esac
done

exit 0
