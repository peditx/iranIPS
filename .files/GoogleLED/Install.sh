#!/bin/sh

# LED control paths (OpenWRT typical paths)
RED="/sys/class/leds/red:brightness"
GREEN="/sys/class/leds/green:brightness"
BLUE="/sys/class/leds/blue:brightness"
[ ! -f "$RED" ] && RED="/sys/class/leds/led0_red/brightness"
[ ! -f "$GREEN" ] && GREEN="/sys/class/leds/led0_green/brightness"
[ ! -f "$BLUE" ] && BLUE="/sys/class/leds/led0_blue/brightness"

# Fallback to simple console output if whiptail not available
show_msg() {
    if command -v whiptail >/dev/null; then
        whiptail --title "$1" --msgbox "$2" 10 50
    else
        echo -e "\n$1:\n$2\n"
        read -p "Press Enter to continue..."
    fi
}

# Simplified LED control
set_led() {
    echo "$1" > "$RED" 2>/dev/null || true
    echo "$2" > "$GREEN" 2>/dev/null || true
    echo "$3" > "$BLUE" 2>/dev/null || true
}

stop_leds() {
    set_led 0 0 0
}

# OpenWRT optimized passwall check
check_passwall() {
    if [ -x "/etc/init.d/passwall" ]; then
        if /etc/init.d/passwall status | grep -q "running"; then
            echo "1"
            return
        fi
    fi
    
    pgrep -x "xray" || pgrep -x "v2ray" || pgrep -x "sing-box" && {
        echo "1"
        return
    }
    
    echo "0"
}

# Ping test optimized for OpenWRT
ping_test() {
    ping -c 1 -W 2 8.8.8.8 2>/dev/null | awk -F'/' '/^rtt/ {print $5}' || echo "999"
}

# Color mixing using busybox compatible syntax
color_mix() {
    stop_leds
    for color in "255 0 0" "0 255 0" "0 0 255"; do
        for i in $(busybox seq 0 5 255); do
            r=$(( ${color%% *} * i / 255 ))
            g=$(( ${color#* } * i / 255 ))
            b=$(( ${color##* } * i / 255 ))
            set_led "$r" "$g" "$b"
            sleep 0.01
        done
        for i in $(busybox seq 255 -5 0); do
            r=$(( ${color%% *} * i / 255 ))
            g=$(( ${color#* } * i / 255 ))
            b=$(( ${color##* } * i / 255 ))
            set_led "$r" "$g" "$b"
            sleep 0.01
        done
    done
    stop_leds
}

# Connection monitor
connection_monitor() {
    while true; do
        ping=$(ping_test | awk '{printf "%.0f", $1*1000}')
        
        if [ "$ping" -ge 1500 ]; then
            set_led 255 0 0       # Red
        elif [ "$ping" -ge 1100 ]; then
            set_led 255 255 0     # Yellow
        elif [ "$ping" -lt 1100 ]; then
            set_led 0 255 0       # Green
        else
            set_led 255 0 0       # Red (error)
        fi
        
        sleep 5
    done
}

# Main menu
main_menu() {
    while true; do
        echo -e "\nOpenWRT LED Control"
        echo "1. Check Passwall Status"
        echo "2. Run Color Test"
        echo "3. Monitor Connection"
        echo "4. Stop All LEDs"
        echo "5. Exit"
        
        read -p "Choose option: " choice
        
        case $choice in
            1) 
                status=$(check_passwall)
                show_msg "Passwall Status" "Status: $([ "$status" = "1" ] && echo "ACTIVE" || echo "INACTIVE")"
                ;;
            2) 
                color_mix &
                show_msg "Color Test" "Running color mixing pattern..."
                kill %1 2>/dev/null
                stop_leds
                ;;
            3) 
                connection_monitor &
                show_msg "Connection Monitor" "Monitoring connection quality..."
                kill %1 2>/dev/null
                stop_leds
                ;;
            4) stop_leds ;;
            5) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
    done
}

# Check if running on OpenWRT
if ! grep -q "OpenWrt" /etc/os-release 2>/dev/null; then
    echo "Warning: This script is optimized for OpenWRT"
fi

# Start the menu
main_menu
