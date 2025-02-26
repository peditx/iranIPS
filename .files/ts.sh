#!/bin/sh

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "این اسکریپت باید با دسترسی root اجرا شود."
    exit 1
fi

# Fetch latest release version from GitHub API
latest_version=$(curl -s https://api.github.com/repos/peditx/luci-app-themeswitch/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$latest_version" ]; then
    echo "خطا در دریافت آخرین نسخه!"
    exit 1
fi

# Base URL for downloads
base_url="https://github.com/peditx/luci-app-themeswitch/releases/download/${latest_version}"

# Package names based on pattern
pkg_main="luci-app-themeswitch_${latest_version}_all.ipk"
pkg_lang="luci-i18n-themeswitch-zh-cn_${latest_version}_all.ipk"

# Temporary directory
tmp_dir="/tmp"
mkdir -p "$tmp_dir"

# Download packages
download_pkg() {
    pkg_name=$1
    echo "دانلود ${pkg_name} ..."
    wget -q "${base_url}/${pkg_name}" -O "${tmp_dir}/${pkg_name}"
    if [ $? -ne 0 ]; then
        echo "خطا در دانلود ${pkg_name}!"
        return 1
    fi
    return 0
}

download_pkg "$pkg_main"
main_dl_status=$?

download_pkg "$pkg_lang"
lang_dl_status=$?

# Install packages
install_pkg() {
    pkg_path=$1
    echo "نصب ${pkg_path} ..."
    opkg install "$pkg_path"
    if [ $? -ne 0 ]; then
        echo "خطا در نصب ${pkg_path}!"
        return 1
    fi
    return 0
}

if [ $main_dl_status -eq 0 ]; then
    install_pkg "${tmp_dir}/${pkg_main}"
fi

if [ $lang_dl_status -eq 0 ]; then
    install_pkg "${tmp_dir}/${pkg_lang}"
fi

# Cleanup
rm -f "${tmp_dir}/${pkg_main}" "${tmp_dir}/${pkg_lang}"
echo "پاکسازی فایل‌های موقت انجام شد."
