#!/bin/sh

opkg update opkg install coreutils-sleep whiptail

mkdir -p /usr/local/LED cd /usr/local/LED

حذف اسکریپت‌های قبلی

rm -f *.sh

تعریف توابع

create_scripts() { cat <<'EOF' > get.sh #!/bin/sh node=$(uci get passwall2.@global[0].node 2>/dev/null) [ -z "$node" ] && echo "node is empty or not found" && exit 1 default_node=$(uci get passwall2."$node".default_node 2>/dev/null) [ -n "$default_node" ] && echo "$default_node" || echo "$node" EOF chmod +x get.sh

cat <<'EOF' > gogo.sh #!/bin/sh status=$(ubus call luci.passwall2 get_status 2>/dev/null) [ -n "$status" ] && echo "$status" | grep -q '"running":true' && echo "1" && exit 0 pgrep -f "xray|v2ray|sing-box" > /dev/null && echo "1" || echo "0" EOF chmod +x gogo.sh

cat <<'EOF' > test.sh #!/bin/sh ournode=$(/usr/local/LED/get.sh) CONFIG=passwall2 LOG_FILE=/tmp/log/$CONFIG.log test_url() { curl --connect-timeout 2 --retry 1 -skL -o /dev/null -w "%{http_code}" "$1" } url_test_node() { node_id=$ournode tmp_port=$(/usr/share/$CONFIG/app.sh get_new_port 61080 tcp,udp) /usr/share/$CONFIG/app.sh run_socks flag="url_test$node_id" node=$node_id bind=127.0.0.1 socks_port=$tmp_port config_file=url_test$node_id.json sleep 1 result=$(curl --connect-timeout 3 -o /dev/null -I -skL -w "%{http_code}:%{time_starttransfer}" -x socks5h://127.0.0.1:$tmp_port https://www.google.com/generate_204) pkill -f "url_test$node_id" echo $result } case "$1" in test_url) test_url "$2" ;; url_test_node) url_test_node ;; esac EOF chmod +x test.sh

cat <<'EOF' > shoe.sh #!/bin/sh RED="/sys/class/leds/LED0_Red" GREEN="/sys/class/leds/LED0_Green" BLUE="/sys/class/leds/LED0_Blue" reset_led_triggers() { echo none > $RED/trigger echo none > $GREEN/trigger echo none > $BLUE/trigger } set_color() { echo 0 > $RED/brightness echo 0 > $GREEN/brightness echo 0 > $BLUE/brightness case "$1" in green) echo 255 > $GREEN/brightness;; yellow) echo 255 > $RED/brightness; echo 255 > $GREEN/brightness;; red) echo 255 > $RED/brightness;; red_blink) echo timer > $RED/trigger; echo 255 > $RED/brightness; echo 500 > $RED/delay_on; echo 500 > $RED/delay_off;; off) ;; esac } get_ping_value() { OUTPUT=$(sh /usr/local/LED/test.sh url_test_node) PING_RAW=$(echo "$OUTPUT" | cut -d ':' -f2) echo "$PING_RAW" | tr -d '.' | cut -c1-4 } while true; do reset_led_triggers PING=$(get_ping_value) if [ "$PING" = "0000" ] || [ "$PING" = "0" ]; then set_color red_blink elif [ "$PING" -ge 1500 ]; then set_color red elif [ "$PING" -ge 1100 ]; then set_color yellow else set_color green fi sleep 10 done EOF chmod +x shoe.sh

cat <<'EOF' > choe.sh #!/bin/sh RED="/sys/class/leds/LED0_Red/brightness" GREEN="/sys/class/leds/LED0_Green/brightness" BLUE="/sys/class/leds/LED0_Blue/brightness" SLEEP="sleep" dim_mix() { R=$1 G=$2 B=$3 for i in $(seq 0 5 255); do echo $((R * i / 255)) > $RED echo $((G * i / 255)) > $GREEN echo $((B * i / 255)) > $BLUE $SLEEP 0.005 done for i in $(seq 255 -5 0); do echo $((R * i / 255)) > $RED echo $((G * i / 255)) > $GREEN echo $((B * i / 255)) > $BLUE $SLEEP 0.005 done echo 0 > $RED echo 0 > $GREEN echo 0 > $BLUE } while true; do dim_mix 255 0 0 dim_mix 0 255 0 dim_mix 0 0 255 dim_mix 255 0 255 dim_mix 255 255 0 dim_mix 255 255 255 done EOF chmod +x choe.sh

cat <<'EOF' > led.sh #!/bin/sh LED_SCRIPT="/usr/local/LED/shoe.sh" CHOS_SCRIPT="/usr/local/LED/choe.sh" CURRENT_STATE="" LED_PID="" stop_led() { echo none > /sys/class/leds/LED0_Red/trigger echo 0 > /sys/class/leds/LED0_Red/brightness echo none > /sys/class/leds/LED0_Green/trigger echo 0 > /sys/class/leds/LED0_Green/brightness echo none > /sys/class/leds/LED0_Blue/trigger echo 0 > /sys/class/leds/LED0_Blue/brightness } kill_running() { [ -n "$LED_PID" ] && kill $LED_PID 2>/dev/null && wait $LED_PID 2>/dev/null stop_led } while true; do STATUS=$(sh /usr/local/LED/gogo.sh) [ "$STATUS" != "$CURRENT_STATE" ] && { kill_running if [ "$STATUS" = "1" ]; then sh $LED_SCRIPT & LED_PID=$! else sh $CHOS_SCRIPT & LED_PID=$! fi CURRENT_STATE="$STATUS" } sleep 10 done EOF chmod +x led.sh }

اجرای ساخت اسکریپت‌ها

create_scripts

افزودن به rc.local در صورت نبود

TARGET_LINE="/usr/local/LED/led.sh &" RC_LOCAL="/etc/rc.local" grep -Fxq "$TARGET_LINE" "$RC_LOCAL" || sed -i "/^exit 0$/i $TARGET_LINE" "$RC_LOCAL" echo "نصب کامل شد."

