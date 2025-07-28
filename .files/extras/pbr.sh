#!/bin/sh

INIT_SCRIPT="/etc/init.d/restart_pbr"

# Check for whiptail
if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail not found. Installing..."
    opkg update && opkg install whiptail
fi

# Main menu
CHOICE=$(whiptail --title "PeDitX's PBR Auto-Restart" --menu "Select an action:" 15 60 4 \
"1" "Install auto-restart script for pbr" \
"2" "Uninstall auto-restart script" 3>&1 1>&2 2>&3)

[ $? -ne 0 ] && exit 1

# INSTALL
if [ "$CHOICE" = "1" ]; then
    # Ask for delay time
    DELAY=$(whiptail --title "Delay Time" --menu "Select delay (seconds) before restarting pbr:" 15 50 7 \
    "5"   "Short delay (5 sec)" \
    "10"  "Standard delay (10 sec)" \
    "15"  "Recommended (15 sec)" \
    "20"  "Longer delay (20 sec)" \
    "30"  "Extended delay (30 sec)" \
    "45"  "Slow systems (45 sec)" \
    "60"  "Very slow systems (60 sec)" 3>&1 1>&2 2>&3)

    [ $? -ne 0 ] && exit 1

    cat << EOF > "$INIT_SCRIPT"
#!/bin/sh /etc/rc.common

START=99
STOP=10

start() {
    logger -t restart_pbr "Delaying $DELAY seconds before restarting pbr"
    sleep $DELAY
    /etc/init.d/pbr restart && logger -t restart_pbr "pbr restarted successfully" || logger -t restart_pbr "Failed to restart pbr"
}
EOF

    chmod +x "$INIT_SCRIPT"
    /etc/init.d/restart_pbr enable

    whiptail --title "Installed" \
             --msgbox "pbr will restart automatically $DELAY seconds after each boot.\n\nScript: /etc/init.d/restart_pbr" 12 60
fi

# UNINSTALL
if [ "$CHOICE" = "2" ]; then
    if [ -f "$INIT_SCRIPT" ]; then
        /etc/init.d/restart_pbr disable
        rm -f "$INIT_SCRIPT"
        whiptail --title "Uninstalled" \
                 --msgbox "The auto-restart script has been removed." 10 50
    else
        whiptail --title "Not Found" \
                 --msgbox "No auto-restart script found to uninstall." 10 50
    fi
fi