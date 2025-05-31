#!/bin/sh

set -x  # Show executed commands

while true; do
    if [ -f "/etc/init.d/passwall" ] && [ -f "/etc/init.d/passwall2" ]; then
        OPTION=$(whiptail --title "PeDitX’s EZPasswall v2.2" --menu "Choose an option:" 15 60 8 \
            "1" "Install Passwall 1" \
            "2" "Install Passwall 2" \
            "3" "Install Passwall 1 + 2" \
            "4" "Update Passwall 1" \
            "5" "Update Passwall 2" \
            "6" "Easy Exroot" \
            "7" "Extra Tools" \
            "8" "Uninstall all Tools" \
            --cancel-button "Exit" \
            3>&1 1>&2 2>&3)
    elif [ -f "/etc/init.d/passwall" ]; then
        OPTION=$(whiptail --title "PeDitX’s EZPasswall v2.2" --menu "Choose an option:" 15 60 8 \
            "1" "Install Passwall 1" \
            "2" "Install Passwall 2" \
            "3" "Install Passwall 1 + 2" \
            "4" "Update Passwall 1" \
            "6" "Easy Exroot" \
            "7" "Extra Tools" \
            "8" "Uninstall all Tools" \
            --cancel-button "Exit" \
            3>&1 1>&2 2>&3)
    elif [ -f "/etc/init.d/passwall2" ]; then
        OPTION=$(whiptail --title "PeDitX’s EZPasswall v2.2" --menu "Choose an option:" 15 60 8 \
            "1" "Install Passwall 1" \
            "2" "Install Passwall 2" \
            "3" "Install Passwall 1 + 2" \
            "5" "Update Passwall 2" \
            "6" "Easy Exroot" \
            "7" "Extra Tools" \
            "8" "Uninstall all Tools" \
            --cancel-button "Exit" \
            3>&1 1>&2 2>&3)
    else
        OPTION=$(whiptail --title "PeDitX’s EZPasswall v2.2" --menu "Choose an option:" 15 60 8 \
            "1" "Install Passwall 1" \
            "2" "Install Passwall 2" \
            "3" "Install Passwall 1 + 2" \
            "6" "Easy Exroot" \
            "7" "Extra Tools" \
            "8" "Uninstall all Tools" \
            --cancel-button "Exit" \
            3>&1 1>&2 2>&3)
    fi

    if [ $? -ne 0 ]; then
        echo "Exiting..."
        exit 0
    fi

    echo "User selected option: $OPTION"  # Print user selection for debugging

    case $OPTION in
        1)
            echo "Installing Passwall 1..."
            rm -f passwall.sh
            wget https://github.com/peditx/iranIPS/raw/refs/heads/main/.files/passwall.sh -O passwall.sh
            chmod +x passwall.sh
            sh passwall.sh
            ;;
        2)
            echo "Installing Passwall 2..."
            rm -f passwall2.sh
            wget https://github.com/peditx/iranIPS/raw/refs/heads/main/.files/passwall2.sh -O passwall2.sh
            chmod +x passwall2.sh
            sh passwall2.sh
            ;;
        3)
            echo "Installing Passwall 1 and 2..."
            rm -f passwalldue.sh
            wget https://github.com/peditx/iranIPS/raw/refs/heads/main/.files/passwalldue.sh -O passwalldue.sh
            chmod +x passwalldue.sh
            sh passwalldue.sh
            ;;
        4)
            echo "Updating Passwall 1..."
            opkg update && opkg upgrade luci-app-passwall
            ;;
        5)
            echo "Updating Passwall 2..."
            opkg update && opkg upgrade luci-app-passwall2
            ;;
        6)
            echo "Running Easy Exroot..."
            curl -ksSL https://github.com/peditx/ezexroot/raw/refs/heads/main/ezexroot.sh -o ezexroot.sh
            sh ezexroot.sh
            ;;
        7)
            echo "Installing Extra Tools..."
            curl -ksSL https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/extras/extra.sh -o extra.sh
            sh extra.sh
            ;;
        8)
            echo "Uninstalling all tools..."
            curl -ksSL https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/core/uninstall.sh -o uninstall.sh
            sh uninstall.sh
            ;;
        *)
            whiptail --title "Error" --msgbox "Invalid option selected!" 8 40
            ;;
    esac
done
