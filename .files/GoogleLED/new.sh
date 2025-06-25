#!/bin/sh

# Installer Script for GoogleWifi LED Controller (Standalone - All in One)
# Works on OpenWrt / BusyBox - No external files needed

INSTALL_DIR="/usr/local/LED"

# Ensure installation directory exists
mkdir -p "$INSTALL_DIR"

# --- Generate: test.sh ---
cat << 'EOF' > "$INSTALL_DIR/test.sh"
#!/bin/sh
URL="$1"
NODE="$2"

if [ -z "$URL" ]; then
  URL="https://www.google.com"
fi

PING_RESULT=$(ping -c 1 -W 1 "$URL" 2>/dev/null | grep time=)

if [ -n "$PING_RESULT" ]; then
  TIME=$(echo "$PING_RESULT" | sed -n 's/.*time=\([^ ]*\).*/\1/p')
  echo "ping:$TIME"
else
  echo "ping:0"
fi
EOF
chmod +x "$INSTALL_DIR/test.sh"

# --- Generate: get.sh ---
cat << 'EOF' > "$INSTALL_DIR/get.sh"
#!/bin/sh
node=$(uci get passwall2.@global[0].node 2>/dev/null)

if [ -z "$node" ]; then
  echo "node is empty or not found"
  exit 1
fi

final_node=$(uci get passwall2."$node".default_node 2>/dev/null)
[ -n "$final_node" ] && echo "$final_node" || echo "$node"
EOF
chmod +x "$INSTALL_DIR/get.sh"

# --- Generate: shoe.sh ---
cat << 'EOF' > "$INSTALL_DIR/shoe.sh"
#!/bin/sh
RED="/sys/class/leds/LED0_Red"
GREEN="/sys/class/leds/LED0_Green"
BLUE="/sys/class/leds/LED0_Blue"

gpv() {
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
    green) echo 255 > $GREEN/brightness ;;
    yellow) echo 255 > $RED/brightness; echo 255 > $GREEN/brightness ;;
    red) echo 255 > $RED/brightness ;;
    red_blink)
      echo timer > $RED/trigger
      echo 255 > $RED/brightness
      echo 500 > $RED/delay_on
      echo 500 > $RED/delay_off
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
  PING=$(gpv)

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
chmod +x "$INSTALL_DIR/shoe.sh"

# --- Generate: choe.sh ---
cat << 'EOF' > "$INSTALL_DIR/choe.sh"
#!/bin/sh
RED="/sys/class/leds/LED0_Red/brightness"
GREEN="/sys/class/leds/LED0_Green/brightness"
BLUE="/sys/class/leds/LED0_Blue/brightness"
SLEEP="sleep"

dim_mix() {
  R=$1; G=$2; B=$3
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
chmod +x "$INSTALL_DIR/choe.sh"

# --- Generate: gogo.sh ---
cat << 'EOF' > "$INSTALL_DIR/gogo.sh"
#!/bin/sh
status=$(ubus call luci.passwall2 get_status 2>/dev/null)
if [ -n "$status" ]; then
  echo "$status" | grep -q '"running":true'
  [ $? -eq 0 ] && echo 1 && exit 0
fi
pgrep -f "xray" > /dev/null || pgrep -f "v2ray" > /dev/null || pgrep -f "sing-box" > /dev/null && echo 1 || echo 0
EOF
chmod +x "$INSTALL_DIR/gogo.sh"

# --- Generate: led.sh ---
cat << 'EOF' > "$INSTALL_DIR/led.sh"
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
chmod +x "$INSTALL_DIR/led.sh"

echo "✅ All LED scripts installed in $INSTALL_DIR and marked executable."
echo "👉 You can now run:  sh $INSTALL_DIR/led.sh"