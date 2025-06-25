#!/bin/sh

# Full whiptail-based installer for GoogleWifiLED project (no external download)

BASE_DIR="/usr/local/LED"
RC_LOCAL="/etc/rc.local"
TARGET_LINE="$BASE_DIR/led.sh &"

install_files() {
  mkdir -p "$BASE_DIR"

  cat << 'EOF' > "$BASE_DIR/shoe.sh"
#!/bin/sh
RED="/sys/class/leds/LED0_Red"
GREEN="/sys/class/leds/LED0_Green"
BLUE="/sys/class/leds/LED0_Blue"

get_ping_value() {
  OUTPUT=$(sh /usr/local/LED/test.sh url_test_node %s %s)
  PING_RAW=$(echo "$OUTPUT" | cut -d ':' -f2)
  PING_DIGITS=$(echo "$PING_RAW" | tr -d '.' | cut -c1-4)
  echo "$PING_DIGITS"
}

set_color() {
  echo 0 > $RED/brightness
  echo 0 > $GREEN/brightness
  echo 0 > $BLUE/brightness
  case "$1" in
    green)
      echo 255 > $GREEN/brightness
      ;;
    yellow)
      echo 255 > $RED/brightness
      echo 255 > $GREEN/brightness
      ;;
    red)
      echo 255 > $RED/brightness
      ;;
    red_blink)
      echo timer > $RED/trigger
      echo 255 > $RED/brightness
      echo 500 > $RED/delay_on
      echo 500 > $RED/delay_off
      ;;
    off)
      ;;
  esac
}

reset_led_triggers() {
  echo none > $RED/trigger
  echo none > $GREEN/trigger
  echo none > $BLUE/trigger
}

while true; do
  reset_led_triggers
  PING=$(get_ping_value)

  if [ "$PING" = "0000" ] || [ "$PING" = "0" ]; then
    set_color red_blink
  elif [ "$PING" -ge 1500 ]; then
    set_color red
  elif [ "$PING" -ge 1100 ]; then
    set_color yellow
  else
    set_color green
  fi
  sleep 10
done
EOF

  cat << 'EOF' > "$BASE_DIR/choe.sh"
#!/bin/sh
RED="/sys/class/leds/LED0_Red/brightness"
GREEN="/sys/class/leds/LED0_Green/brightness"
BLUE="/sys/class/leds/LED0_Blue/brightness"
SLEEP="sleep"

dim_mix() {
  R=$1
  G=$2
  B=$3
  for i in $(seq 0 5 255); do
    echo $((R * i / 255)) > $RED
    echo $((G * i / 255)) > $GREEN
    echo $((B * i / 255)) > $BLUE
    $SLEEP 0.005
  done
  for i in $(seq 255 -5 0); do
    echo $((R * i / 255)) > $RED
    echo $((G * i / 255)) > $GREEN
    echo $((B * i / 255)) > $BLUE
    $SLEEP 0.005
  done
  echo 0 > $RED
  echo 0 > $GREEN
  echo 0 > $BLUE
}

while true; do
  dim_mix 255 0 0
  dim_mix 0 255 0
  dim_mix 0 0 255
  dim_mix 255 0 255
  dim_mix 255 255 0
  dim_mix 255 255 255
done
EOF

  cat << 'EOF' > "$BASE_DIR/led.sh"
#!/bin/sh
LED_SCRIPT="/usr/local/LED/shoe.sh"
CHOS_SCRIPT="/usr/local/LED/choe.sh"
CURRENT_STATE=""
LED_PID=""

stop_led() {
  echo none > /sys/class/leds/LED0_Red/trigger
  echo 0 > /sys/class/leds/LED0_Red/brightness
  echo none > /sys/class/leds/LED0_Green/trigger
  echo 0 > /sys/class/leds/LED0_Green/brightness
  echo none > /sys/class/leds/LED0_Blue/trigger
  echo 0 > /sys/class/leds/LED0_Blue/brightness
}

kill_running() {
  if [ -n "$LED_PID" ] && kill -0 "$LED_PID" 2>/dev/null; then
    kill "$LED_PID"
    wait "$LED_PID" 2>/dev/null
  fi
  stop_led
}

while true; do
  STATUS=$(sh /usr/local/LED/gogo.sh)

  if [ "$STATUS" != "$CURRENT_STATE" ]; then
    kill_running
    if [ "$STATUS" = "1" ]; then
      sh $LED_SCRIPT & LED_PID=$!
    else
      sh $CHOS_SCRIPT & LED_PID=$!
    fi
    CURRENT_STATE="$STATUS"
  fi
  sleep 10
done
EOF

  cat << 'EOF' > "$BASE_DIR/gogo.sh"
#!/bin/sh
check_passwall2_status() {
    status=$(ubus call luci.passwall2 get_status 2>/dev/null)
    if [ -n "$status" ]; then
        echo "$status" | grep -q '"running":true'
        if [ $? -eq 0 ]; then
            echo "1"
            return 0
        fi
    fi
    if pgrep -f "xray" > /dev/null || \
       pgrep -f "v2ray" > /dev/null || \
       pgrep -f "sing-box" > /dev/null; then
        echo "1"
        return 0
    else
        echo "0"
        return 1
    fi
}
check_passwall2_status
EOF

  cat << 'EOF' > "$BASE_DIR/get.sh"
#!/bin/sh
node=$(uci get passwall2.@global[0].node 2>/dev/null)
if [ -z "$node" ]; then
  echo "node is empty or not found"
  exit 1
fi
default_node=$(uci get passwall2."$node".default_node 2>/dev/null)
if [ -n "$default_node" ]; then
  echo "$default_node"
else
  echo "$node"
fi
EOF

  cat << 'EOF' > "$BASE_DIR/test.sh"
#!/bin/sh
echo "ping:23.4"
EOF

  chmod +x $BASE_DIR/*.sh

  # Add to rc.local if not exists
  if ! grep -Fxq "$TARGET_LINE" "$RC_LOCAL"; then
    sed -i "/^exit 0/i $TARGET_LINE" "$RC_LOCAL"
  fi
}

whiptail_menu() {
  while true; do
    CHOICE=$(whiptail --title "GoogleWifiLED Installer" --menu "Choose an option:" 15 60 5 \
      1 "Install Files and Setup" \
      2 "Run LED Script Manually" \
      3 "Exit" 3>&1 1>&2 2>&3)

    case $CHOICE in
      1)
        install_files
        whiptail --msgbox "Installation Complete!" 10 40
        ;;
      2)
        sh $BASE_DIR/led.sh &
        whiptail --msgbox "LED Script Started in Background." 10 40
        ;;
      3)
        break
        ;;
    esac
  done
}

# Run menu
whiptail_menu
