#!/bin/sh

# تنظیمات LED برای OpenWRT
set_led() {
    # راه‌های مختلف کنترل LED در مدل‌های مختلف
    [ -f "/sys/class/leds/red/brightness" ] && echo $1 > /sys/class/leds/red/brightness
    [ -f "/sys/class/leds/green/brightness" ] && echo $2 > /sys/class/leds/green/brightness
    [ -f "/sys/class/leds/blue/brightness" ] && echo $3 > /sys/class/leds/blue/brightness
    [ -f "/sys/class/leds/led0:red/brightness" ] && echo $1 > /sys/class/leds/led0:red/brightness
    [ -f "/sys/class/leds/led0:green/brightness" ] && echo $2 > /sys/class/leds/led0:green/brightness
    [ -f "/sys/class/leds/led0:blue/brightness" ] && echo $3 > /sys/class/leds/led0:blue/brightness
}

# خاموش کردن همه LEDها
stop_leds() {
    set_led 0 0 0
}

# بررسی وضعیت Passwall (سازگار با OpenWRT)
check_passwall() {
    if [ -f "/etc/init.d/passwall" ]; then
        /etc/init.d/passwall status | grep -q "running" && echo "فعال" || echo "غیرفعال"
    else
        echo "نصب نشده"
    fi
}

# تست پینگ ساده شده
ping_test() {
    ping -c 1 -W 2 8.8.8.8 2>/dev/null | awk -F'/' '/^rtt/ {print $5" ms"}' || echo "اتصال ناموفق"
}

# منوی ساده متنی
show_menu() {
    clear
    echo "-------------------------------------"
    echo "   کنترل LED برای OpenWRT"
    echo "-------------------------------------"
    echo "1. نمایش وضعیت Passwall"
    echo "2. تست LED (رنگ‌های مختلف)"
    echo "3. نمایش کیفیت اتصال"
    echo "4. خاموش کردن LEDها"
    echo "5. خروج"
    echo "-------------------------------------"
    read -p "لطفاً عدد گزینه مورد نظر را وارد کنید: " choice

    case $choice in
        1)
            clear
            echo "وضعیت Passwall: $(check_passwall)"
            read -p "برای ادامه Enter بزنید..."
            ;;
        2)
            clear
            echo "در حال اجرای تست LED..."
            set_led 255 0 0  # قرمز
            sleep 1
            set_led 0 255 0  # سبز
            sleep 1
            set_led 0 0 255  # آبی
            sleep 1
            stop_leds
            echo "تست LED کامل شد"
            read -p "برای ادامه Enter بزنید..."
            ;;
        3)
            clear
            echo "کیفیت اتصال: $(ping_test)"
            # نمایش وضعیت با LED
            ping=$(ping_test | awk '{print $1}')
            if [ "$ping" = "اتصال" ]; then
                set_led 255 0 0  # قرمز برای اتصال ناموفق
            elif [ "${ping%%.*}" -gt 150 ]; then
                set_led 255 165 0  # نارنجی
            else
                set_led 0 255 0  # سبز
            fi
            read -p "برای ادامه Enter بزنید..."
            ;;
        4)
            stop_leds
            echo "تمامی LEDها خاموش شدند"
            sleep 1
            ;;
        5)
            stop_leds
            exit 0
            ;;
        *)
            echo "گزینه نامعتبر!"
            sleep 1
            ;;
    esac
}

# شروع برنامه
while true; do
    show_menu
