#!/bin/sh

set -x  # Show executed commands

# Function to display exit message in a whiptail box
show_exit_message() {
    whiptail --title "PeDitX's EZPasswall" --msgbox "For the latest updates and information, please visit our GitHub page or Telegram channel:\n\nhttps://t.me/peditx" 12 60
    clear
    exit 0
}

while true; do
    if [ -f "/etc/init.d/passwall" ] && [ -f "/etc/init.d/passwall2" ]; then
        # Both Passwalls installed
        OPTION=$(whiptail --title "PeDitX’s EZPasswall v3.1.2" --menu "Choose an option:" 20 60 11 \
            "1" "Install Passwall 1" \
            "2" "Install Passwall 2" \
            "3" "Install Passwall 1 + 2" \
            "4" "Update Passwall 1" \
            "5" "Update Passwall 2" \
            "6" "Update Both Passwalls" \
            "7" "Easy Exroot" \
            "8" "Extra Tools" \
            "9" "OpenWrt x86/Raspberry Pi Optimization Toolkit" \
            "10" "DNS Changer" \
            "11" "Uninstall all Tools" \
            --cancel-button "Exit" \
            3>&1 1>&2 2>&3)
    elif [ -f "/etc/init.d/passwall" ]; then
        # Only Passwall 1 installed
        OPTION=$(whiptail --title "PeDitX’s EZPasswall v3.1.2" --menu "Choose an option:" 20 60 10 \
            "1" "Install Passwall 1" \
            "2" "Install Passwall 2" \
            "3" "Install Passwall 1 + 2" \
            "4" "Update Passwall 1" \
            "7" "Easy Exroot" \
            "8" "Extra Tools" \
            "9" "OpenWrt x86/Raspberry Pi Optimization Toolkit" \
            "10" "DNS Changer" \
            "11" "Uninstall all Tools" \
            --cancel-button "Exit" \
            3>&1 1>&2 2>&3)
    elif [ -f "/etc/init.d/passwall2" ]; then
        # Only Passwall 2 installed
        OPTION=$(whiptail --title "PeDitX’s EZPasswall v3.1.2" --menu "Choose an option:" 20 60 10 \
            "1" "Install Passwall 1" \
            "2" "Install Passwall 2" \
            "3" "Install Passwall 1 + 2" \
            "5" "Update Passwall 2" \
            "7" "Easy Exroot" \
            "8" "Extra Tools" \
            "9" "OpenWrt x86/Raspberry Pi Optimization Toolkit" \
            "10" "DNS Changer" \
            "11" "Uninstall all Tools" \
            --cancel-button "Exit" \
            3>&1 1>&2 2>&3)
    else
        # No Passwalls installed
        OPTION=$(whiptail --title "PeDitX’s EZPasswall v3.1.2" --menu "Choose an option:" 20 60 9 \
            "1" "Install Passwall 1" \
            "2" "Install Passwall 2" \
            "3" "Install Passwall 1 + 2" \
            "7" "Easy Exroot" \
            "8" "Extra Tools" \
            "9" "OpenWrt x86/Raspberry Pi Optimization Toolkit" \
            "10" "DNS Changer" \
            "11" "Uninstall all Tools" \
            --cancel-button "Exit" \
            3>&1 1>&2 2>&3)
    fi

    # Check if user pressed Exit button
    if [ $? -ne 0 ]; then
        show_exit_message
    fi

    echo "User selected option: $OPTION"

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
            opkg update
            opkg upgrade luci-app-passwall
            ;;
        5)
            echo "Updating Passwall 2..."
            opkg update
            opkg upgrade luci-app-passwall2
            ;;
        6)
            echo "Updating Both Passwalls..."
            opkg update
            opkg upgrade luci-app-passwall luci-app-passwall2
            ;;
        7)
            echo "Running Easy Exroot..."
            curl -ksSL https://github.com/peditx/ezexroot/raw/refs/heads/main/ezexroot.sh -o ezexroot.sh
            sh ezexroot.sh
            ;;
        8)
            echo "Installing Extra Tools..."
            curl -ksSL https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/extras/extra.sh -o extra.sh
            sh extra.sh
            ;;
        9)
            echo "Running OpenWrt x86/Raspberry Pi Optimization Toolkit..."
            rm -f opt.sh
            wget https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/x86/opt.sh -O opt.sh
            chmod +x opt.sh
            sh opt.sh
            ;;
        10)
            echo "DNS Changer ..."
            curl -ksSL https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/dns.sh -o dns.sh
            sh dns.sh
            ;;
        11)
            echo "Uninstalling all tools..."
            curl -ksSL https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/core/uninstall.sh -o uninstall.sh
            sh uninstall.sh
            ;;
        *)
            whiptail --title "Error" --msgbox "Invalid option selected!" 8 40
            ;;
    esac
done
