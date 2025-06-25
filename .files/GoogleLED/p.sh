#!/bin/sh

# نصب و به‌روزرسانی پیش‌نیازها
echo "Updating package lists and installing dependencies..."
opkg update
opkg install coreutils-sleep whiptail curl

# ساخت مسیر نصب
BASE_DIR="/usr/local/LED"
mkdir -p "$BASE_DIR"
cd "$BASE_DIR" || exit 1

# حذف فایل‌های قبلی
rm -f *

# ایجاد اسکریپت network_test.sh
cat << 'EOF' > network_test.sh
#!/bin/sh
ournode=`/usr/local/LED/get_node.sh`
CONFIG=passwall2
LOG_FILE=/tmp/log/$CONFIG.log
echolog() {
  local d="$(date "+%Y-%m-%d %H:%M:%S")"
  echo -e "$d: $1" >> $LOG_FILE
}
config_n_get() {
  local ret=$(uci -q get "${CONFIG}.${1}.${2}" 2>/dev/null)
  echo "${ret:=$3}"
}
test_url() {
  local url=$1
  local try=1
  [ -n "$2" ] && try=$2
  local timeout=2
  [ -n "$3" ] && timeout=$3
  local extra_params=$4
  curl --help all | grep "\-\-retry-all-errors" > /dev/null
  [ $? = 0 ] && extra_params="--retry-all-errors ${extra_params}"
  status=$(/usr/bin/curl -I -o /dev/null -skL $extra_params --connect-timeout ${timeout} --retry ${try} -w %{http_code} "$url")
  case "$status" in 204|200) status=200;; esac
  echo $status
}
url_test_node() {
  result=0
  local node_id=$ournode
  local _type=$(echo $(config_n_get ${node_id} type) | tr 'A-Z' 'a-z')
  [ -n "${_type}" ] && {
    local _tmp_port=$(/usr/share/${CONFIG}/app.sh get_new_port 61080 tcp,udp)
    /usr/share/${CONFIG}/app.sh run_socks flag="url_test_${node_id}" node=${node_id} bind=127.0.0.1 socks_port=${_tmp_port} config_file=url_test_${node_id}.json
    local curlx="socks5h://127.0.0.1:${_tmp_port}"
    sleep 1
    result=$(curl --connect-timeout 3 -o /dev/null -I -skL -w "%{http_code}:%{time_starttransfer}" -x $curlx "https://www.google.com/generate_204")
    pgrep -af "url_test_${node_id}" | awk '! /network_test\.sh/{print $1}' | xargs kill -9 >/dev/null 2>&1
    rm -rf "/tmp/etc/${CONFIG}/url_test_${node_id}.json"
  }
  echo $result
}
arg1=$1
shift
case $arg1 in
  test_url) test_url "$@" ;;
  url_test_node) url_test_node "$@" ;;
esac
EOF

# ایجاد get_node.sh
cat << 'EOF' > get_node.sh
#!/bin/sh
node=$(uci get passwall2.@global[0].node 2>/dev/null)
[ -z "$node" ] && echo "node is empty or not found" && exit 1
default_node=$(uci get passwall2."$node".default_node 2>/dev/null)
[ -n "$default_node" ] && echo "$default_node" || echo "$node"
EOF

# ایجاد check_passwall.sh
cat << 'EOF' > check_passwall.sh
#!/bin/sh
check_passwall2_status() {
  status=$(ubus call luci.passwall2 get_status 2>/dev/null)
  [ -n "$status" ] && echo "$status" | grep -q '"running":true' && echo "1" && return 0
  if pgrep -f "xray" > /dev/null || pgrep -f "v2ray" > /dev/null || pgrep -f "sing-box" > /dev/null; then
    echo "1"
    return 0
  else
    echo "0"
    return 1
  fi
}
check_passwall2_status
EOF

# ایجاد ping_led.sh
cat << 'EOF' > ping_led.sh
#!/bin/sh
RED="/sys/class/leds/LED0_Red"
GREEN="/sys/class/leds/LED0_Green"
BLUE="/sys/class/leds/LED0_Blue"
get_ping_value() {
  OUTPUT=$(sh /usr/local/LED/network_test.sh url_test_node)
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
      echo 500 > $RED/delay_off ;;
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

# ایجاد rainbow_led.sh
cat << 'EOF' > rainbow_led.sh
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

# ایجاد led_manager.sh
cat << 'EOF' > led_manager.sh
#!/bin/sh
PING_SCRIPT="/usr/local/LED/ping_led.sh"
RAINBOW_SCRIPT="/usr/local/LED/rainbow_led.sh"
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
  STATE=$(sh /usr/local/LED/check_passwall.sh)
  if [ "$STATE" = "1" ]; then
    if [ "$CURRENT_STATE" != "online" ]; then
      kill_running
      sh "$PING_SCRIPT" &
      LED_PID=$!
      CURRENT_STATE="online"
    fi
  else
    if [ "$CURRENT_STATE" != "offline" ]; then
      kill_running
      sh "$RAINBOW_SCRIPT" &
      LED_PID=$!
      CURRENT_STATE="offline"
    fi
  fi
  sleep 10
done
EOF

# دادن اجازه اجرا به همه اسکریپت‌ها
chmod +x *.sh

echo "✅ Installation completed successfully."
