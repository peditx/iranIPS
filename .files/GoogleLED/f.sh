#!/bin/sh

set -e

INSTALL_DIR="/usr/local/LED"
RC_LOCAL="/etc/rc.local"
LED_LINE="$INSTALL_DIR/led.sh &"

# Create LED directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Copy all necessary scripts to LED dir
copy_scripts() {
  cp ./led.sh "$INSTALL_DIR/led.sh"
  cp ./gogo.sh "$INSTALL_DIR/gogo.sh"
  cp ./choe.sh "$INSTALL_DIR/choe.sh"
  cp ./shoe.sh "$INSTALL_DIR/shoe.sh"
  cp ./test.sh "$INSTALL_DIR/test.sh"
  cp ./get.sh "$INSTALL_DIR/get.sh"
  chmod +x "$INSTALL_DIR/"*.sh
}

# Ensure LED script runs on boot
add_to_rc_local() {
  grep -Fxq "$LED_LINE" "$RC_LOCAL" || {
    sed -i "/^exit 0/i $LED_LINE" "$RC_LOCAL"
  }
}

# Remove all files and startup line
uninstall_all() {
  sed -i "\|$LED_LINE|d" "$RC_LOCAL"
  rm -rf "$INSTALL_DIR"
  echo "Uninstalled."
  sleep 1
}

# LED test function
run_test() {
  sh "$INSTALL_DIR/choe.sh" &
  pid=$!
  sleep 10
  kill "$pid"
}

# Start main LED script
start_led() {
  sh "$INSTALL_DIR/led.sh" &
  echo "Started LED monitor"
}

# Stop LED script
stop_led() {
  pkill -f "$INSTALL_DIR/led.sh" 2>/dev/null
  echo "Stopped LED monitor"
}

# Menu
while true; do
  OPTION=$(whiptail --title "Google Wifi LED" --menu "Select an option:" 15 60 6 \
    "1" "Install LED system" \
    "2" "Test LED colors" \
    "3" "Start LED Monitor" \
    "4" "Stop LED Monitor" \
    "5" "Uninstall" \
    "0" "Exit" 3>&1 1>&2 2>&3)

  case "$OPTION" in
    1)
      opkg update
      opkg install coreutils-sleep curl
      copy_scripts
      add_to_rc_local
      whiptail --msgbox "Installation complete." 10 40
      ;;
    2)
      run_test
      ;;
    3)
      start_led
      ;;
    4)
      stop_led
      ;;
    5)
      uninstall_all
      ;;
    0)
      clear
      exit 0
      ;;
    *)
      whiptail --msgbox "Invalid selection." 10 40
      ;;
  esac
done