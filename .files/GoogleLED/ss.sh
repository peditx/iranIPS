#!/bin/sh

Set installation directory

#####
#!/bin/sh

# تعیین مسیر نصب
BASE_DIR="/usr/local/GoogleWifiLED"
[ -z "$BASE_DIR" ] && echo "❌ مسیر نصب تعریف نشده!" && exit 1
mkdir -p "$BASE_DIR" || { echo "❌ ساخت دایرکتوری ناموفق بود!"; exit 1; }
cd "$BASE_DIR" || exit 1
####

Dependencies

opkg update opkg install coreutils-sleep whiptail curl

Create get_node.sh

cat << 'EOF' > get_node.sh #!/bin/sh node=$(uci get passwall2.@global[0].node 2>/dev/null) [ -z "$node" ] && echo "node is empty or not found" && exit 1 default_node=$(uci get passwall2."$node".default_node 2>/dev/null) [ -n "$default_node" ] && echo "$default_node" || echo "$node" EOF

Create check_node.sh

cat << 'EOF' > check_node.sh #!/bin/sh ournode=/usr/local/GoogleWifiLED/get_node.sh CONFIG=passwall2 LOG_FILE=/tmp/log/$CONFIG.log echolog() { local d="$(date "+%Y-%m-%d %H:%M:%S")" echo -e "$d: $1" >> $LOG_FILE } config_n_get() { local ret=$(uci -q get "${CONFIG}.${1}.${2}" 2>/dev/null) echo "${ret:=$3}" } test_url() { local url=$1 local try=1 [ -n "$2" ] && try=$2 local timeout=2 [ -n "$3" ] && timeout=$3 local extra_params=$4 curl --help all | grep "--retry-all-errors" > /dev/null [ $? == 0 ] && extra_params="--retry-all-errors ${extra_params}" status=$(/usr/bin/curl -I -o /dev/null -skL $extra_params --connect-timeout ${timeout} --retry ${try} -w %{http_code} "$url") case "$status" in 204|200) status=200;; esac echo $status } url_test_node() { result=0 local node_id=$ournode local _type=$(echo $(config_n_get ${node_id} type) | tr 'A-Z' 'a-z') [ -n "${type}" ] && { local tmp_port=$(/usr/share/${CONFIG}/app.sh get_new_port 61080 tcp,udp) /usr/share/${CONFIG}/app.sh run_socks flag="url_test${node_id}" node=${node_id} bind=127.0.0.1 socks_port=${tmp_port} config_file=url_test${node_id}.json local curlx="socks5h://127.0.0.1:${tmp_port}" sleep 1s result=$(curl --connect-timeout 3 -o /dev/null -I -skL -w "%{http_code}:%{time_starttransfer}" -x $curlx "https://www.google.com/generate_204") pgrep -af "url_test${node_id}" | awk '! /check_node.sh/{print $1}' | xargs kill -9 >/dev/null 2>&1 rm -rf "/tmp/etc/${CONFIG}/url_test${node_id}.json" } echo $result } arg1=$1 shift case $arg1 in test_url) test_url "$@" ;; url_test_node) url_test_node "$@" ;; esac EOF

Create led_control.sh

cat << 'EOF' > led_control.sh #!/bin/sh LED_PATH=/sys/class/leds RED="$LED_PATH/LED0_Red" GREEN="$LED_PATH/LED0_Green" BLUE="$LED_PATH/LED0_Blue"

reset_leds() { echo none > $RED/trigger echo none > $GREEN/trigger echo none > $BLUE/trigger echo 0 > $RED/brightness echo 0 > $GREEN/brightness echo 0 > $BLUE/brightness }

set_color() { reset_leds case "$1" in red) echo 255 > $RED/brightness ;; green) echo 255 > $GREEN/brightness ;; blue) echo 255 > $BLUE/brightness ;; yellow) echo 255 > $RED/brightness; echo 255 > $GREEN/brightness ;; purple) echo 255 > $RED/brightness; echo 255 > $BLUE/brightness ;; white) echo 255 > $RED/brightness; echo 255 > $GREEN/brightness; echo 255 > $BLUE/brightness ;; blink) echo timer > $RED/trigger echo 255 > $RED/brightness echo 500 > $RED/delay_on echo 500 > $RED/delay_off ;; off) reset_leds ;; esac }

PING_RAW=$(sh /usr/local/GoogleWifiLED/check_node.sh url_test_node | cut -d ':' -f2) PING=$(echo "$PING_RAW" | tr -d '.' | cut -c1-4) [ "$PING" = "0000" ] && set_color blink && exit [ "$PING" -ge 1500 ] && set_color red && exit [ "$PING" -ge 1100 ] && set_color yellow && exit set_color green EOF

Create uninstall.sh

cat << 'EOF' > uninstall.sh #!/bin/sh rm -rf /usr/local/GoogleWifiLED sed -i '/GoogleWifiLED/d' /etc/rc.local echo "✅ Uninstalled successfully." EOF

Create menu.sh

cat << 'EOF' > menu.sh #!/bin/sh while true; do CHOICE=$(whiptail --title "GoogleWifiLED Control" --menu "Choose an option:" 15 60 6 
"1" "Test Node and Set Color" 
"2" "Set Custom Color" 
"3" "Uninstall" 
"4" "Exit" 3>&1 1>&2 2>&3)

case $CHOICE in 1) sh /usr/local/GoogleWifiLED/led_control.sh ;; 2) COLOR=$(whiptail --title "Set LED Color" --menu "Choose color:" 15 60 6 
"red" "Red" "green" "Green" "blue" "Blue" 
"yellow" "Yellow" "purple" "Purple" "white" "White" 
"off" "Turn Off" 3>&1 1>&2 2>&3) sh /usr/local/GoogleWifiLED/led_control.sh "$COLOR" ;; 3) sh /usr/local/GoogleWifiLED/uninstall.sh && exit ;; 4) exit ;; esac done EOF

Permissions

chmod +x *.sh

Add to startup

RC_LOCAL="/etc/rc.local" TARGET_LINE="sh /usr/local/GoogleWifiLED/menu.sh &" grep -Fxq "$TARGET_LINE" "$RC_LOCAL" || sed -i "/^exit 0/i $TARGET_LINE" "$RC_LOCAL"

echo "✅ GoogleWifiLED installed with menu interface."

