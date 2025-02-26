#!/bin/sh

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Fetch latest release version from GitHub API
latest_version=$(curl -s https://api.github.com/repos/peditx/luci-app-themeswitch/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$latest_version" ]; then
    echo "Failed to fetch the latest version!"
    exit 1
fi

# Base URL for downloads
base_url="https://github.com/peditx/luci-app-themeswitch/releases/download/${latest_version}"

# Package name based on pattern
pkg_main="luci-app-themeswitch_${latest_version}_all.ipk"

# Temporary directory
tmp_dir="/tmp"
mkdir -p "$tmp_dir"

# Download package
echo "Downloading ${pkg_main} ..."
wget -q "${base_url}/${pkg_main}" -O "${tmp_dir}/${pkg_main}"
if [ $? -ne 0 ]; then
    echo "Failed to download ${pkg_main}!"
    exit 1
fi

# Install package
echo "Installing ${pkg_main} ..."
opkg install "${tmp_dir}/${pkg_main}"
if [ $? -ne 0 ]; then
    echo "Failed to install ${pkg_main}!"
    exit 1
fi

# Cleanup
rm -f "${tmp_dir}/${pkg_main}"
echo "Temporary files cleaned up."
