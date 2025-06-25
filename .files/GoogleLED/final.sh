#!/bin/sh

INSTALL_DIR="/usr/local/LED" RC_LOCAL="/etc/rc.local" STARTUP_CMD="$INSTALL_DIR/led.sh &"

ensure_requirements() { opkg update opkg install coreutils-sleep whiptail curl }

create_install_dir() { mkdir -p "$INSTALL_DIR" }

write_file() { cat <<'EOF' > "$INSTALL_DIR/$1" $2 EOF chmod +x "$INSTALL_DIR/$1" }

add_to_startup() { grep -Fxq "$STARTUP_CMD" "$RC_LOCAL" || sed -i "/^exit 0$/i $STARTUP_CMD" "$RC_LOCAL" }

remove_from_startup() { sed -i "/$STARTUP_CMD/d" "$RC_LOCAL" }

uninstall_all() { pkill -f led.sh remove_from_startup rm -rf "$INSTALL_DIR" whiptail --msgbox "Uninstallation complete." 10 40 }

run_test() { sh "$INSTALL_DIR/test.sh" url_test_node | whiptail --title "Test Result" --msgbox "Result: $(cat -)" 10 60 }

choose_mode() { CHOICE=$(whiptail --title "LED Mode" --menu "Choose LED mode:" 15 50 4 
"ping" "LED changes based on ping value" 
"loop" "LED loops through colors" 
"solid" "Choose a solid color" 
3>&1 1>&2 2>&3)

case $CHOICE in
    ping)
        cp "$INSTALL_DIR/shoe.sh" "$INSTALL_DIR/active.sh"
        ;;
    loop)
        cp "$INSTALL_DIR/choe.sh" "$INSTALL_DIR/active.sh"
        ;;
    solid)
        choose_color
        ;;
esac

cat <<EOF > "$INSTALL_DIR/led.sh"

#!/bin/sh sh "$INSTALL_DIR/gogo.sh" sh "$INSTALL_DIR/active.sh" EOF chmod +x "$INSTALL_DIR/led.sh" add_to_startup whiptail --msgbox "Mode applied successfully." 10 40 }

choose_color() { COLOR=$(whiptail --title "Choose Color" --menu "Select LED Color:" 15 40 6 
"red" "Solid Red" 
"green" "Solid Green" 
"blue" "Solid Blue" 
"yellow" "Red + Green" 
"purple" "Red + Blue" 
"white" "All colors" 
3>&1 1>&2 2>&3)

cat <<EOF > "$INSTALL_DIR/active.sh"

#!/bin/sh RED="/sys/class/leds/LED0_Red/brightness" GREEN="/sys/class/leds/LED0_Green/brightness" BLUE="/sys/class/leds/LED0_Blue/brightness" echo 0 > $RED; echo 0 > $GREEN; echo 0 > $BLUE case "$COLOR" in red) echo 255 > $RED ;; green) echo 255 > $GREEN ;; blue) echo 255 > $BLUE ;; yellow) echo 255 > $RED; echo 255 > $GREEN ;; purple) echo 255 > $RED; echo 255 > $BLUE ;; white) echo 255 > $RED; echo 255 > $GREEN; echo 255 > $BLUE ;; esac EOF chmod +x "$INSTALL_DIR/active.sh" }

main_menu() { while true; do OPTION=$(whiptail --title "GoogleWifiLED Installer" --menu "Select an option:" 18 50 10 
"1" "Install project" 
"2" "Choose LED mode" 
"3" "Run test" 
"4" "Uninstall project" 
"0" "Exit" 
3>&1 1>&2 2>&3)

case $OPTION in
        1)
            ensure_requirements
            create_install_dir
            write_file "get.sh" "<GET_SH_CONTENT>"
            write_file "test.sh" "<TEST_SH_CONTENT>"
            write_file "gogo.sh" "<GOGO_SH_CONTENT>"
            write_file "shoe.sh" "<SHOE_SH_CONTENT>"
            write_file "choe.sh" "<CHOE_SH_CONTENT>"
            chmod +x "$INSTALL_DIR"/*.sh
            whiptail --msgbox "Installation complete." 10 40
            ;;
        2)
            choose_mode
            ;;
        3)
            run_test
            ;;
        4)
            uninstall_all
            ;;
        0)
            exit 0
            ;;
    esac
done

}

main_menu

