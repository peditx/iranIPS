#!/bin/sh

# -- Install dependencies --
echo "Updating package list and installing dependencies..."
opkg update
opkg install coreutils-sleep whiptail curl

# -- Setup base directory --
BASE_DIR="/usr/local/LED"
mkdir -p "$BASE_DIR"
cd "$BASE_DIR" || exit 1

# -- Clear previous files --
rm -f *

# -- Write the files one by one --

# shoe.sh (LED control script)
cat > shoe.sh << 'EOF'
#!/bin/sh

RED="/sys/class/leds/LED0_Red"
GREEN="/sys/class/leds/LED0_Green"
BLUE="/sys/class/leds/LED0_Blue"

get_ping_value() {
  OUTPUT=$(sh /usr/local/LED/test.sh url_test_node)
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

chmod +x shoe.sh

# led.sh (for example, similar structure - can be customized)
cat > led.sh << 'EOF'
#!/bin/sh
# Example led.sh content (customize as needed)
echo "LED script running..."
EOF
chmod +x led.sh

# gogo.sh (example placeholder)
cat > gogo.sh << 'EOF'
#!/bin/sh
# Example gogo.sh content
echo "Gogo script running..."
EOF
chmod +x gogo.sh

# get.sh (example placeholder)
cat > get.sh << 'EOF'
#!/bin/sh
# Example get.sh content
echo "Getting node info..."
echo 1
EOF
chmod +x get.sh

# choe.sh (example placeholder)
cat > choe.sh << 'EOF'
#!/bin/sh
# Example choe.sh content
echo "Choe script running..."
EOF
chmod +x choe.sh

# test.sh (the full test.sh script you gave me, with slight cleanup)
cat > test.sh << 'EOF'
#!/bin/sh

ournode=$(/usr/local/LED/get.sh)

CONFIG=passwall2
LOG_FILE=/tmp/log/${CONFIG}.log

echolog() {
  local d="$(date "+%Y-%m-%d %H:%M:%S")"
  echo -e "$d: $1" >> $LOG_FILE
}

config_n_get() {
  local ret=$(uci -q get "${CONFIG}.${1}.${2}" 2>/dev/null)
  echo "${ret:=$3}"
}

config_t_get() {
  local index=0
  [ -n "$4" ] && index=$4
  local ret=$(uci -q get $CONFIG.@$1[$index].$2 2>/dev/null)
  echo ${ret:=$3}
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
  case "$status" in
    204|200)
      status=200
      ;;
  esac
  echo $status
}

test_proxy() {
  result=0
  status=$(test_url "https://www.google.com/generate_204" ${retry_num} ${connect_timeout})
  if [ "$status" = "200" ]; then
    result=0
  else
    status2=$(test_url "https://www.baidu.com" ${retry_num} ${connect_timeout})
    if [ "$status2" = "200" ]; then
      result=1
    else
      result=2
      ping -c 3 -W 1 223.5.5.5 > /dev/null 2>&1
      [ $? -eq 0 ] && {
        result=1
      }
    fi
  fi
  echo $result
}

url_test_node() {
  result=0
  local node_id=$ournode
  local _type=$(echo $(config_n_get ${node_id} type) | tr 'A-Z' 'a-z')
  [ -n "${_type}" ] && {
    local _tmp_port=$(/usr/share/${CONFIG}/app.sh get_new_port 61080 tcp,udp)
    /usr/share/${CONFIG}/app.sh run_socks flag="url_test_${node_id}" node=${node_id} bind=127.0.0.1 socks_port=${_tmp_port} config_file=url_test_${node_id}.json
    local curlx="socks5h://127.0.0.1:${_tmp_port}"
    sleep 1s
    result=$(curl --connect-timeout 3 -o /dev/null -I -skL -w "%{http_code}:%{time_starttransfer}" -x $curlx "https://www.google.com/generate_204")
    pgrep -af "url_test_${node_id}" | awk '! /test\.sh/{print $1}' | xargs kill -9 >/dev/null 2>&1
    rm -rf "/tmp/etc/${CONFIG}/url_test_${node_id}.json"
  }
  echo $result
}

test_node() {
  local node_id=$ournode
  local _type=$(echo $(config_n_get ${node_id} type) | tr 'A-Z' 'a-z')
  [ -n "${_type}" ] && {
    local _tmp_port=$(/usr/share/${CONFIG}/app.sh get_new_port 61080 tcp,udp)
    /usr/share/${CONFIG}/app.sh run_socks flag="test_node_${node_id}" node=${node_id} bind=127.0.0.1 socks_port=${_tmp_port} config_file=test_node_${node_id}.json
    local curlx="socks5h://127.0.0.1:${_tmp_port}"
    sleep 1s
    _proxy_status=$(test_url "https://www.google.com/generate_204" ${retry_num} ${connect_timeout} "-x $curlx")
    pgrep -af "test_node_${node_id}" | awk '! /test\.sh/{print $1}' | xargs kill -9 >/dev/null 2>&1
    rm -rf "/tmp/etc/${CONFIG}/test_node_${node_id}.json"
    if [ "${_proxy_status}" -eq 200 ]; then
      return 0
    fi
  }
  return 1
}

arg1=$1
shift
case $arg1 in
  test_url)
    test_url $@
    ;;
  url_test_node)
    url_test_node $@
    ;;
esac
EOF

chmod +x test.sh

# -- Create the main controller script --
cat > led_manager.sh << 'EOF'
#!/bin/sh

BASE_DIR="/usr/local/LED"
LED_SCRIPT="$BASE_DIR/shoe.sh"
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
  # Example: Always state 1 (can be changed to detect actual state)
  STATUS=1

  if [ "$STATUS" != "$CURRENT_STATE" ]; then
    kill_running
    if [ "$STATUS" = "1" ]; then
      sh $LED_SCRIPT & LED_PID=$!
    else
      :
    fi
    CURRENT_STATE="$STATUS"
  fi
  sleep 10
done
EOF

chmod +x led_manager.sh

# -- Start the main manager --
echo "Starting LED manager..."
nohup sh "$BASE_DIR/led_manager.sh" > /tmp/led_manager.log 2>&1 &

echo "Installation and startup complete."
