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

# Display IP configuration menu using whiptail
while true; do
    choice=$(whiptail --title "IP Configuration" --menu "Select IP configuration:" 15 60 5 \
    "1" "Set IP to 10.1.1.1" \
    "2" "Set IP to 11.1.1.1" \
    "3" "Set IP to 192.168.0.1" \
    "4" "Custom IP address" \
    "5" "Don't change IP" 3>&1 1>&2 2>&3)

    # Check if the user pressed Cancel (exit code 1)
    if [ $? -ne 0 ]; then
        break
    fi

    case $choice in
        1)
            uci set network.lan.ipaddr='10.1.1.1'
            uci commit network
            whiptail --msgbox "IP set to 10.1.1.1" 8 45
            ;;
        2)
            uci set network.lan.ipaddr='11.1.1.1'
            uci commit network
            whiptail --msgbox "IP set to 11.1.1.1" 8 45
            ;;
        3)
            uci set network.lan.ipaddr='192.168.0.1'
            uci commit network
            whiptail --msgbox "IP set to 192.168.0.1" 8 45
            ;;
        4)
            custom_ip=$(whiptail --inputbox "Enter custom IP address:" 8 45 3>&1 1>&2 2>&3)
            # Check if the custom IP is not empty
            if [ -n "$custom_ip" ]; then
                uci set network.lan.ipaddr="$custom_ip"
                uci commit network
                whiptail --msgbox "Custom IP set to $custom_ip" 8 45
            else
                whiptail --msgbox "No IP entered. IP not changed." 8 45
            fi
            ;;
        5)
            whiptail --msgbox "IP not changed" 8 45
            ;;
        *)
            whiptail --msgbox "Invalid choice, please try again." 8 45
            ;;
    esac

    whiptail --msgbox "Restarting network to apply changes..." 8 45
    /etc/init.d/network restart
done
