#!/bin/sh

Paths

INSTALL_DIR="/usr/local/LED" RC_LOCAL="/etc/rc.local" LED_SCRIPT="$INSTALL_DIR/led.sh"

Check for whiptail

if ! command -v whiptail >/dev/null 2>&1; then opkg update && opkg install whiptail fi

Create installation directory

mkdir -p "$INSTALL_DIR"

Stop any running LED script

pkill -f "$LED_SCRIPT"

Function to write embedded file content

write_file() { filename="$1" content="$2" echo "$content" > "$INSTALL_DIR/$filename" chmod +x "$INSTALL_DIR/$filename" }

--- Embedded Scripts ---

get.sh

write_file "get.sh" '#!/bin/sh node=$(uci get passwall2.@global[0].node 2>/dev/null) [ -z "$node" ] && echo "node is empty or not found" && exit 1 default_node=$(uci get passwall2."$node".default_node 2>/dev/null) [ -n "$default_node" ] && echo "$default_node" || echo "$node"'

gogo.sh

write_file "gogo.sh" '#!/bin/sh status=$(ubus call luci.passwall2 get_status 2>/dev/null) if echo "$status" | grep -q '"running":true'; then echo "1" else pgrep -f "xray|v2ray|sing-box" > /dev/null && echo "1" || echo "0" fi'

test.sh

write_file "test.sh" '#!/bin/sh ournode=$($INSTALL_DIR/get.sh) curl --connect-timeout 3 -o /dev/null -I -skL -w "%{http_code}:%{time_starttransfer}" -x socks5h://127.0.0.1:61080 https://www.google.com/generate_204'

shoe.sh

write_file "shoe.sh" '#!/bin/sh RED="/sys/class/leds/LED0_Red" GREEN="/sys/class/leds/LED0_Green" BLUE="/sys/class/leds/LED0_Blue" get_ping() { PING_RAW=$(sh $INSTALL_DIR/test.sh | cut -d ":" -f2) echo "${PING_RAW//./}" | cut -c1-4 } set_color() { echo 0 > $RED/brightness echo 0 > $GREEN/brightness echo 0 > $BLUE/brightness case "$1" in green) echo 255 > $GREEN/brightness;; yellow) echo 255 > $RED/brightness; echo 255 > $GREEN/brightness;; red) echo 255 > $RED/brightness;; blink) echo timer > $RED/trigger echo 255 > $RED/brightness echo 500 > $RED/delay_on echo 500 > $RED/delay_off;; esac } reset_leds() { echo none > $RED/trigger echo none > $GREEN/trigger echo none > $BLUE/trigger } while true; do reset_leds PING=$(get_ping) case $PING in 0000|0) set_color blink;; 15*|2*) set_color red;; 11*|14*) set_color yellow;; *) set_color green;; esac sleep 10 done'

choe.sh

write_file "choe.sh" '#!/bin/sh RED="/sys/class/leds/LED0_Red/brightness" GREEN="/sys/class/leds/LED0_Green/brightness" BLUE="/sys/class/leds/LED0_Blue/brightness" fade() { R=$1; G=$2; B=$3 for i in $(seq 0 5 255); do echo $((R * i / 255)) > $RED echo $((G * i / 255)) > $GREEN echo $((B * i / 255)) > $BLUE sleep 0.005 done for i in $(seq 255 -5 0); do echo $((R * i / 255)) > $RED echo $((G * i / 255)) > $GREEN echo $((B * i / 255)) > $BLUE sleep 0.005 done } while true; do fade 255 0 0; fade 0 255 0; fade 0 0 255 fade 255 255 0; fade 255 0 255; fade 255 255 255 done'

led.sh

write_file "led.sh" '#!/bin/sh SCRIPT1="$INSTALL_DIR/shoe.sh" SCRIPT2="$INSTALL_DIR/choe.sh" STATE="" PID="" stop_led() { echo none > /sys/class/leds/LED0_Red/trigger echo 0 > /sys/class/leds/LED0_Red/brightness echo none > /sys/class/leds/LED0_Green/trigger echo 0 > /sys/class/leds/LED0_Green/brightness echo none > /sys/class/leds/LED0_Blue/trigger echo 0 > /sys/class/leds/LED0_Blue/brightness } kill_running() { [ -n "$PID" ] && kill "$PID" 2>/dev/null && wait "$PID" stop_led } while true; do STATUS=$(sh $INSTALL_DIR/gogo.sh) [ "$STATUS" != "$STATE" ] && { kill_running [ "$STATUS" = "1" ] && sh "$SCRIPT1" & PID=$! || sh "$SCRIPT2" & PID=$! STATE="$STATUS" } sleep 10 done'

Add to rc.local if not exists

if ! grep -Fxq "$LED_SCRIPT &" "$RC_LOCAL"; then sed -i "/^exit 0/i $LED_SCRIPT &" "$RC_LOCAL" fi

Menu

while true; do CHOICE=$(whiptail --title "GoogleWifi LED Setup" --menu "Choose an option:" 20 60 10 
"1" "Install or Reset" 
"2" "Test LED" 
"3" "Remove All" 
"4" "Exit" 3>&1 1>&2 2>&3)

case $CHOICE in 1) echo "Installed scripts in $INSTALL_DIR";; 2) sh "$INSTALL_DIR/choe.sh" & sleep 10 pkill -f "$INSTALL_DIR/choe.sh";; 3) pkill -f "$INSTALL_DIR/" rm -rf "$INSTALL_DIR" sed -i "/$LED_SCRIPT/d" "$RC_LOCAL" echo "Removed.";; 4) exit;; esac done

