#!/bin/sh

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Create /var/lock directory if it doesn't exist
if [ ! -d "/var/lock" ]; then
    echo "Creating /var/lock directory..."
    mkdir -p /var/lock
fi

# Fetch latest release version from GitHub API
latest_version=$(curl -s https://api.github.com/repos/peditx/luci-app-themeswitch/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$latest_version" ]; then
    echo "Failed to fetch the latest version!"
    exit 1
fi

# Get all supported architectures from opkg
arch_list=$(opkg print-architecture | awk '{print $2}')

# Find the first matching architecture in the available package list
pkg_arch=""
for arch in $arch_list; do
    case "$arch" in
        aarch64_cortex-a53|aarch64_cortex-a72|aarch64_generic|\
        arm_cortex-a15_neon-vfpv4|arm_cortex-a5_vfpv4|arm_cortex-a7|\
        arm_cortex-a7_neon-vfpv4|arm_cortex-a8_vfpv3|arm_cortex-a9|\
        arm_cortex-a9_neon|arm_cortex-a9_vfpv3-d16|mipsel_24kc|\
        mipsel_74kc|mipsel_mips32|mips_24kc|mips_4kec|mips_mips32|x86_64)
            pkg_arch="$arch"
            break
            ;;
    esac
done

if [ -z "$pkg_arch" ]; then
    echo "Unsupported CPU architecture detected!"
    exit 1
fi

# Base URL for downloads
base_url="https://github.com/peditx/luci-app-themeswitch/releases/download/${latest_version}"

# Package name based on pattern
pkg_main="luci-app-themeswitch_${latest_version}_${pkg_arch}.ipk"

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
