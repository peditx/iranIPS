#!/bin/sh

INSTALL_DIR="/usr/local/LED" RC_LOCAL="/etc/rc.local" TARGET_LINE="$INSTALL_DIR/led.sh &"

install_files() { mkdir -p "$INSTALL_DIR"

cp ./shoe.sh "$INSTALL_DIR/"
cp ./led.sh "$INSTALL_DIR/"
cp ./gogo.sh "$INSTALL_DIR/"
cp ./choe.sh "$INSTALL_DIR/"
cp ./test.sh "$INSTALL_DIR/"
cp ./get.sh "$INSTALL_DIR/"

chmod +x "$INSTALL_DIR"/*.sh

grep -Fxq "$TARGET_LINE" "$RC_LOCAL" || sed -i "/^exit 0/i $TARGET_LINE" "$RC_LOCAL"

whiptail --msgbox "Installation completed successfully." 10 40

}

remove_files() { sed -i "|$TARGET_LINE|d" "$RC_LOCAL" rm -rf "$INSTALL_DIR" whiptail --msgbox "All LED-related files have been removed." 10 40 }

run_test() { TEST_RESULT=$(sh "$INSTALL_DIR/test.sh" test_url https://www.google.com/generate_204) whiptail --msgbox "Test result:\n$TEST_RESULT" 10 60 }

choose_color() { COLOR=$(whiptail --title "Manual LED Color Selection" --menu "Choose a color to apply manually:" 15 50 6 \ "green" "Green (Good connection)" 
"yellow" "Yellow (Moderate connection)" 
"red" "Red (Poor connection)" 
"red_blink" "Blinking Red (No connection)" 
"off" "Turn off LEDs" 3>&1 1>&2 2>&3)

if [ $? -eq 0 ]; then
    # Create a temporary manual LED script that sets the color once
    TMP_SCRIPT="/tmp/manual_led.sh"
    cat <<EOF > "$TMP_SCRIPT"

#!/bin/sh RED="/sys/class/leds/LED0_Red" GREEN="/sys/class/leds/LED0_Green" BLUE="/sys/class/leds/LED0_Blue" echo none > $RED/trigger echo none > $GREEN/trigger echo none > $BLUE/trigger echo 0 > $RED/brightness echo 0 > $GREEN/brightness echo 0 > $BLUE/brightness case "$COLOR" in green) echo 255 > $GREEN/brightness ;; yellow) echo 255 > $RED/brightness echo 255 > $GREEN/brightness ;; red) echo 255 > $RED/brightness ;; red_blink) echo timer > $RED/trigger echo 255 > $RED/brightness echo 500 > $RED/delay_on echo 500 > $RED/delay_off ;; off) ;; # Already turned off esac EOF chmod +x "$TMP_SCRIPT" sh "$TMP_SCRIPT" rm "$TMP_SCRIPT" fi }

main_menu() { while true; do CHOICE=$(whiptail --title "GoogleWifi LED Control" --menu "Choose an action:" 20 60 10 
"1" "Install LED System" 
"2" "Uninstall LED System" 
"3" "Run Connectivity Test" 
"4" "Manual LED Color Change" 
"5" "Exit" 3>&1 1>&2 2>&3)

case "$CHOICE" in
        1)
            install_files
            ;;
        2)
            remove_files
            ;;
        3)
            run_test
            ;;
        4)
            choose_color
            ;;
        5)
            break
            ;;
        *)
            whiptail --msgbox "Invalid option selected." 10 40
            ;;
    esac
done

}

main_menu

