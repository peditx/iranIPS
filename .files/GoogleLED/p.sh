#!/bin/sh

RED="/sys/class/leds/LED0_Red"
GREEN="/sys/class/leds/LED0_Green"
BLUE="/sys/class/leds/LED0_Blue"

LED_PID=""

# تابع تنظیم رنگ LED
set_color() {
  echo 0 > $RED/brightness
  echo 0 > $GREEN/brightness
  echo 0 > $BLUE/brightness
  echo none > $RED/trigger
  echo none > $GREEN/trigger
  echo none > $BLUE/trigger

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
      # خاموش کردن LEDها
      ;;
  esac
}

# تابع گرفتن زمان پاسخ (time_starttransfer) از گوگل
get_ping_value() {
  OUTPUT=$(curl -o /dev/null -s -w "%{http_code}:%{time_starttransfer}" "https://www.google.com/generate_204")
  PING_RAW=$(echo "$OUTPUT" | cut -d ':' -f2)
  PING_DIGITS=$(echo "$PING_RAW" | tr -d '.' | cut -c1-4)
  echo "$PING_DIGITS"
}

# اجرای حلقه بررسی پینگ و تنظیم LED
run_led_loop() {
  while true; do
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
}

# توقف اجرای چراغ LED در صورت اجرا
stop_led_loop() {
  if [ -n "$LED_PID" ] && kill -0 "$LED_PID" 2>/dev/null; then
    kill "$LED_PID"
    wait "$LED_PID" 2>/dev/null
  fi
  set_color off
}

# منوی whiptail
while true; do
  CHOICE=$(whiptail --title "GoogleWifiLED Control Panel" --menu "Choose an option:" 15 60 4 \
    "1" "Start LED Ping Monitor" \
    "2" "Stop LED Ping Monitor" \
    "3" "Show Ping Value" \
    "4" "Exit" 3>&1 1>&2 2>&3)

  case $CHOICE in
    1)
      if [ -n "$LED_PID" ] && kill -0 "$LED_PID" 2>/dev/null; then
        whiptail --msgbox "LED Ping Monitor is already running." 8 50
      else
        run_led_loop &
        LED_PID=$!
        whiptail --msgbox "Started LED Ping Monitor." 8 40
      fi
      ;;
    2)
      stop_led_loop
      LED_PID=""
      whiptail --msgbox "Stopped LED Ping Monitor." 8 40
      ;;
    3)
      PING=$(get_ping_value)
      whiptail --msgbox "Current Ping Value (time_starttransfer): $PING" 8 50
      ;;
    4)
      stop_led_loop
      exit 0
      ;;
    *)
      whiptail --msgbox "Invalid Option!" 8 40
      ;;
  esac
done
