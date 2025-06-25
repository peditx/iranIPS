#!/bin/sh

INSTALL_DIR="/usr/local/LED"

# Create install directory if not exists
mkdir -p "$INSTALL_DIR"

# Create test.sh
cat << 'EOF' > "$INSTALL_DIR/test.sh"
#!/bin/sh

TARGET=
IP=

if [ -n "$1" ]; then
  TARGET="$1"
fi
if [ -n "$2" ]; then
  IP="$2"
fi

if [ -z "$TARGET" ]; then
  echo "ping:0"
  exit 1
fi

if [ -n "$IP" ]; then
  ping_result=$(ping -c 1 -W 1 -I "$IP" "$TARGET" 2>/dev/null)
else
  ping_result=$(ping -c 1 -W 1 "$TARGET" 2>/dev/null)
fi

if echo "$ping_result" | grep -q 'time='; then
  ping_value=$(echo "$ping_result" | grep 'time=' | sed -n 's/.*time=\([^ ]*\).*/\1/p')
  echo "ping:$ping_value"
else
  echo "ping:0"
fi
EOF

# Create get.sh
cat << 'EOF' > "$INSTALL_DIR/get.sh"
#!/bin/sh

node=$(uci get passwall2.@global[0].node 2>/dev/null)

if [ -z "$node" ]; then
  echo "node is empty or not found"
  exit 1
fi

default_node=$(uci get passwall2."$node".default_node 2>/dev/null)

if [ -n "$default_node" ]; then
  echo "$default_node"
else
  echo "$node"
fi
EOF

# Create gogo.sh
cat << 'EOF' > "$INSTALL_DIR/gogo.sh"
#!/bin/sh

check_passwall2_status() {
    status=$(ubus call luci.passwall2 get_status 2>/dev/null)

    if [ -n "$status" ]; then
        echo "$status" | grep -q '"running":true'
        if [ $? -eq 0 ]; then
            echo "1"
            return 0
        fi
    fi

    if pgrep -f "xray" > /dev/null || \
       pgrep -f "v2ray" > /dev/null || \
       pgrep -f "sing-box" > /dev/null; then
        echo "1"
        return 0
    else
        echo "0"
        return 1
    fi
}

check_passwall2_status
EOF

# Create choe.sh
cat << 'EOF' > "$INSTALL_DIR/choe.sh"
#!/bin/sh

RED="/sys/class/leds/LED0_Red/brightness"
GREEN="/sys/class/leds/LED0_Green/brightness"
BLUE="/sys/class/leds/LED0_Blue/brightness"
SLEEP="sleep"

dim_mix() {
  R=
  G=
  B=
  for i in 