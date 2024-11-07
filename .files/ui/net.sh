#!/bin/sh

# نصب Netdata
if ! command -v netdata >/dev/null 2>&1; then
    echo "Netdata not found. Installing..."
    # به روزرسانی بسته‌ها
    opkg update
    # نصب Netdata
    opkg install netdata
fi

# راه‌اندازی Netdata به صورت خودکار
/etc/init.d/netdata enable
/etc/init.d/netdata start

# ایجاد فایل کنترل‌کننده Lua برای دکمه Monitoring
cat << 'EOF' > /usr/lib/lua/luci/controller/monitoring.lua
module("luci.controller.monitoring", package.seeall)

function index()
    entry({"admin", "status", "monitoring"}, call("action_monitoring"), _("Monitoring"), 99)
end

function action_monitoring()
    local http = require "luci.http"
    http.redirect("http://" .. luci.sys.exec("uci get network.lan.ipaddr"):gsub("\n", "") .. ":19999")
end
EOF

# راه‌اندازی مجدد uhttpd برای اعمال تغییرات
/etc/init.d/uhttpd restart
