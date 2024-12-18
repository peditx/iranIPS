#!/bin/bash

# Path to the WiFi configuration file
wifi_config="/etc/config/wireless"

# Clear the terminal
clear

# Display a welcome banner
whiptail --title "WiFi Configurator" --msgbox "Welcome to WiFi Configurator\n\nMade By PeDitX" 10 50

# Let the user choose the WiFi band
band=$(whiptail --title "WiFi Band Selection" --menu "Choose the WiFi band to configure:" 15 50 3 \
"2G" "Enable 2.4GHz only" \
"5G" "Enable 5GHz only" \
"Both" "Enable both 2.4GHz and 5GHz" 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    whiptail --title "Cancelled" --msgbox "No changes were made." 10 40
    exit 0
fi

# Get WiFi name from the user
new_ssid=$(whiptail --title "WiFi Configurator" --inputbox "Enter the new WiFi name (SSID):" 10 50 3>&1 1>&2 2>&3)
exit_status=$?
if [ $exit_status -ne 0 ]; then
    whiptail --title "Exit" --msgbox "Exiting script..." 10 40
    exit 1
fi

# Get WiFi password from the user
new_password=$(whiptail --title "WiFi Configurator" --passwordbox "Enter the new WiFi password:" 10 50 3>&1 1>&2 2>&3)
exit_status=$?
if [ $exit_status -ne 0 ]; then
    whiptail --title "Exit" --msgbox "Exiting script..." 10 40
    exit 1
fi

# Apply settings based on the chosen band
if [[ "$band" == "2G" ]]; then
    # Configure 2.4GHz WiFi
    uci set wireless.radio0.disabled='0' # Enable 2.4GHz
    uci set wireless.radio1.disabled='1' # Disable 5GHz
    uci set wireless.@wifi-iface[0].ssid="$new_ssid"
    uci set wireless.@wifi-iface[0].key="$new_password"
elif [[ "$band" == "5G" ]]; then
    # Configure 5GHz WiFi
    uci set wireless.radio0.disabled='1' # Disable 2.4GHz
    uci set wireless.radio1.disabled='0' # Enable 5GHz
    uci set wireless.@wifi-iface[1].ssid="${new_ssid}-5G"
    uci set wireless.@wifi-iface[1].key="$new_password"
elif [[ "$band" == "Both" ]]; then
    # Configure both 2.4GHz and 5GHz WiFi
    uci set wireless.radio0.disabled='0' # Enable 2.4GHz
    uci set wireless.radio1.disabled='0' # Enable 5GHz
    uci set wireless.@wifi-iface[0].ssid="$new_ssid"
    uci set wireless.@wifi-iface[0].key="$new_password"
    uci set wireless.@wifi-iface[1].ssid="${new_ssid}-5G"
    uci set wireless.@wifi-iface[1].key="$new_password"
fi

# Set security to WPA/WPA2 PSK (CCMP)
uci set wireless.@wifi-iface[0].encryption='psk2'
uci set wireless.@wifi-iface[0].auth='CCMP'
uci set wireless.@wifi-iface[1].encryption='psk2'
uci set wireless.@wifi-iface[1].auth='CCMP'

# Commit changes
uci commit wireless

# Restart WiFi services
wifi reload

# Display success message
whiptail --title "Success" --msgbox "WiFi settings have been successfully updated." 10 50

# Prompt user for continuation
if (whiptail --title "Next Step" --yesno "Do you want to download and run the extra script?" 10 50); then
    rm -f extra.sh && wget https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/extras/extra.sh && chmod 777 extra.sh && sh extra.sh
else
    whiptail --title "Exit" --msgbox "Exiting script..." 10 40
    exit 0
fi
