#!/bin/sh
# iranips.sh - route Iranian traffic direct in passwall2 (25.12 and 26.x, Xray or sing-box).
#
#   ./iranips.sh              keep whatever geo source passwall2 already uses (default)
#   ./iranips.sh chocolate4u  switch passwall2 to Chocolate4U's Iran-optimised geo data first
#
# One run: stage UCI -> validate geo tags with the installed Xray -> commit -> start -> verify.
# If anything fails, the configuration you had before is restored.
#
# Verified against the live sources (2026-10):
#   - Xray refuses to start on an unknown geo code: geodat_loader.go / rule_parser.go call
#     checkFile() at config parse time and ToUpper() the code first.
#   - geosite:ir exists ONLY in Chocolate4U data. Loyalsoldier (passwall2 default URL and
#     the v2ray-geosite OpenWrt package) and v2fly dlc.dat do NOT ship it -> using it
#     blindly is what makes Xray not start. geoip:ir and geosite:category-*-ir exist in
#     all three, so they are always safe.
#   - passwall2 reads shunt rules through util_xray.lua / util_sing-box.lua: on 26.x a rule
#     is applied only when node.shunt_group == rule.group; on 25.12 there is no group filter,
#     only the node.<rule name> mapping. domainStrategy=IPOnDemand is required or geoip:ir
#     never matches a domain request.

set -e

VERSION=2.0.1
APP=passwall2
APP_PATH=/usr/share/passwall2
LOG=/tmp/iranips.log
BAK=/tmp/iranips.bak.$$
TEST_JSON=/tmp/iranips.test.$$.json
TEST_ERR=/tmp/iranips.test.$$.err
GEO_SOURCE=${1:-auto}
COMMITTED=0
PRUNED=""

log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG"; }
warn() { log "WARN: $*"; }
die()  { log "ERROR: $*"; exit 1; }

bin_ok() { case "$1" in */*) [ -x "$1" ] ;; *) command -v "$1" >/dev/null 2>&1 ;; esac; }

cleanup() { rm -f "$BAK" "$TEST_JSON" "$TEST_ERR"; }

restore_backup() {
	log "Restoring the previous passwall2 configuration..."
	uci -q revert $APP 2>/dev/null || true
	[ -f "$BAK" ] || return 0
	cp -f "$BAK" /etc/config/$APP
	uci commit $APP 2>/dev/null || true
	/etc/init.d/$APP restart >/dev/null 2>&1 || true
	log "Previous configuration restored."
}

on_exit() {
	st=$?
	if [ "$st" -ne 0 ]; then
		log "version: $VERSION"
		if [ "$COMMITTED" = 1 ]; then
			restore_backup
			log "RESULT: FAILED - the previous configuration was restored, nothing changed."
		else
			uci -q revert $APP 2>/dev/null || true
			log "Nothing was committed, staged changes dropped."
			log "RESULT: FAILED - nothing was changed."
		fi
	fi
	cleanup
}
trap 'on_exit' EXIT

# The node non-Iran traffic goes to: whatever was the main node before
# (or the shunt node's own default_node, so re-running keeps your proxy).
# _urltest / _balancing are followed into their first member - they cannot be a
# shunt default node themselves, and falling back to _direct would switch the
# proxy off entirely.
resolve_default_node() {
	_n=$1
	_d=0
	while [ -n "$_n" ] && [ "$_d" -lt 4 ]; do
		_d=$((_d + 1))
		case "$_n" in _*) printf '_direct\n'; return 0 ;; esac
		_p=$(uci -q get "$APP.$_n.protocol" 2>/dev/null || true)
		case "$_p" in
			'') printf '_direct\n'; return 0 ;;
			_urltest|_balancing)
				_next=$(uci -q get "$APP.$_n.urltest_node" 2>/dev/null || true)
				if [ -z "$_next" ]; then
					_next=$(uci -q get "$APP.$_n.balancing_node" 2>/dev/null || true)
				fi
				if [ -z "$_next" ]; then
					_next=$(uci -q get "$APP.$_n.fallback_node" 2>/dev/null || true)
				fi
				_n=${_next%% *}
				;;
			_shunt)
				_next=$(uci -q get "$APP.$_n.default_node" 2>/dev/null || true)
				_n=${_next%% *}
				;;
			*) printf '%s\n' "$_n"; return 0 ;;
		esac
	done
	printf '_direct\n'
}

# newline list on stdin -> JSON array of strings (values are escaped: the rule
# lists contain regexp anchors, and "\." is not a valid JSON escape)
json_list() {
	_out=''
	while IFS= read -r _line; do
		if [ -z "$_line" ]; then continue; fi
		case "$_line" in \#*) continue ;; esac
		_line=$(printf '%s' "$_line" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
		if [ -n "$_out" ]; then _out="$_out,"; fi
		_out="$_out\"$_line\""
	done
	printf '%s' "$_out"
}

build_test_config() {
	printf '{"log":{"loglevel":"none"},'
	printf '"inbounds":[{"tag":"t","listen":"127.0.0.1","port":19999,"protocol":"socks","settings":{"udp":true}}],'
	printf '"outbounds":[{"protocol":"freedom","tag":"direct"}],'
	printf '"routing":{"domainStrategy":"IPOnDemand","rules":[{"domain":[%s],"ip":[%s],"network":"tcp,udp","outboundTag":"direct"}]}}' \
		"$(printf '%s\n' "$DOMAINS" | json_list)" "$(printf '%s\n' "$IPS" | json_list)"
	printf '\n'
}

# run the installed Xray against the test config; diagnostics land in $TEST_ERR.
# passwall2 reads the test result from stdout (app.sh: ... run -test -c ... > file),
# so both streams are captured - and if this form is not supported at all
# (25.12's app.sh never calls -test), the legacy form is tried as a fallback.
xray_test() {
	: > "$TEST_ERR"
	XRAY_LOCATION_ASSET="$ASSET" "$XRAY_BIN" run -test -c "$1" >"$TEST_ERR" 2>&1
	rc=$?
	[ "$rc" -eq 0 ] && return 0
	if [ ! -s "$TEST_ERR" ] || grep -qiE 'unknown command|unknown flag|usage:' "$TEST_ERR"; then
		if grep -qi 'failed to' "$TEST_ERR" 2>/dev/null; then
			return 1
		fi
		XRAY_LOCATION_ASSET="$ASSET" "$XRAY_BIN" -test -config "$1" >"$TEST_ERR" 2>&1
		rc=$?
		[ "$rc" -eq 0 ] && return 0
	fi
	if [ ! -s "$TEST_ERR" ]; then
		printf 'xray produced no output at all (exit status %s)\n' "$rc" > "$TEST_ERR"
	fi
	return 1
}

core_running() {
	if command -v pgrep >/dev/null 2>&1; then
		if pgrep -f 'xray run' >/dev/null 2>&1; then return 0; fi
		if pgrep -f 'sing-box run' >/dev/null 2>&1; then return 0; fi
		return 1
	fi
	ps w 2>/dev/null | grep -E '[x]ray run|[s]ing-box run' >/dev/null 2>&1
}

wait_core() {
	# give the previous core process time to die, otherwise a stale one could
	# be mistaken for a successful start
	log "Waiting up to 30 seconds for the core process to come up..."
	sleep 2
	_i=0
	while [ $_i -lt 15 ]; do
		if core_running; then return 0; fi
		sleep 2
		_i=$((_i + 1))
	done
	return 1
}

case "$GEO_SOURCE" in
	auto|chocolate4u) : ;;
	*) echo "usage: $0 [auto|chocolate4u]" >&2; exit 2 ;;
esac

log "=== IranIPS v$VERSION start (geo source: $GEO_SOURCE) ==="

# --- 0. sanity ----------------------------------------------------------
command -v uci >/dev/null 2>&1 || die "uci not found - run this on the OpenWrt router"
[ -f /etc/config/$APP ] || die "/etc/config/$APP missing - install luci-app-passwall2 first"
[ -x /etc/init.d/$APP ] || die "/etc/init.d/$APP missing - install luci-app-passwall2 first"
cp -f /etc/config/$APP "$BAK"

# --- 1. geo data --------------------------------------------------------
# OpenWrt 24.10+ (25.12, ...) ships apk instead of opkg - both must work.
# Paths are probed too, so it still works when PATH is minimal (rpcd/LuCI).
find_bin() {
	for _c in "$@"; do
		case "$_c" in
			*/*)
				if [ -x "$_c" ]; then printf '%s\n' "$_c"; return 0; fi
				;;
			*)
				if command -v "$_c" >/dev/null 2>&1; then command -v "$_c"; return 0; fi
				;;
		esac
	done
	return 1
}

APK_BIN=$(find_bin apk /sbin/apk /usr/sbin/apk || true)
OPKG_BIN=$(find_bin opkg /bin/opkg /usr/bin/opkg /sbin/opkg || true)
if [ -n "$APK_BIN" ]; then
	PKG_KIND=apk
elif [ -n "$OPKG_BIN" ]; then
	PKG_KIND=opkg
fi

pkg_add() {
	case "$PKG_KIND" in
		apk) "$APK_BIN" add "$1" >/dev/null 2>&1 || warn "could not install $1" ;;
		opkg) "$OPKG_BIN" install "$1" >/dev/null 2>&1 || warn "could not install $1" ;;
		*) warn "no package manager found - $1 must already be installed" ;;
	esac
}

if [ -n "$PKG_KIND" ]; then
	log "Installing geo data packages with $PKG_KIND..."
	if [ "$PKG_KIND" = apk ]; then
		"$APK_BIN" update >/dev/null 2>&1 || warn "apk update failed (offline?) - using what is installed"
	else
		"$OPKG_BIN" update >/dev/null 2>&1 || warn "opkg update failed (offline?) - using what is installed"
	fi
	for p in v2ray-geoip v2ray-geosite; do
		pkg_add "$p"
	done
	pkg_add v2ray-geosite-ir
else
	warn "neither apk nor opkg found - geo data must already be installed"
fi

# --- 2. which core ------------------------------------------------------
CUR_NODE=$(uci -q get $APP.@global[0].node 2>/dev/null || true)
CUR_TYPE=$(uci -q get "$APP.$CUR_NODE.type" 2>/dev/null | tr 'A-Z' 'a-z' || true)
XRAY_BIN=$(uci -q get $APP.@global_app[0].xray_file 2>/dev/null || echo /usr/bin/xray)
SB_BIN=$(uci -q get $APP.@global_app[0].sing_box_file 2>/dev/null || echo /usr/bin/sing-box)
ASSET=$(uci -q get $APP.@global_rules[0].v2ray_location_asset 2>/dev/null || echo /usr/share/v2ray)
case "$ASSET" in */) : ;; *) ASSET="$ASSET/" ;; esac

if ! bin_ok "$XRAY_BIN" && ! bin_ok "$SB_BIN"; then
	die "neither Xray nor sing-box binary found ($XRAY_BIN / $SB_BIN)"
fi
NODE_TYPE=Xray
case "$CUR_TYPE" in
	sing-box) NODE_TYPE=sing-box ;;
	xray) NODE_TYPE=Xray ;;
esac
if [ "$NODE_TYPE" = Xray ] && ! bin_ok "$XRAY_BIN"; then NODE_TYPE=sing-box; fi
if [ "$NODE_TYPE" = sing-box ] && ! bin_ok "$SB_BIN"; then NODE_TYPE=Xray; fi
log "Core: $NODE_TYPE"

# where non-Iran traffic goes - resolved before the old node is removed below
START_NODE=$CUR_NODE
if [ "$CUR_NODE" = MainShunt ]; then
	START_NODE=$(uci -q get "$APP.MainShunt.default_node" 2>/dev/null || true)
	if [ -z "$START_NODE" ]; then START_NODE=$CUR_NODE; fi
fi
DEF_NODE=$(resolve_default_node "$START_NODE")

[ -f "${ASSET}geoip.dat" ] || die "missing ${ASSET}geoip.dat - install v2ray-geoip (apk add / opkg install)"
[ -f "${ASSET}geosite.dat" ] || die "missing ${ASSET}geosite.dat - install v2ray-geosite (apk add / opkg install)"

if [ "$NODE_TYPE" = sing-box ]; then
	GEOVIEW=$(uci -q get $APP.@global_app[0].geoview_file 2>/dev/null || echo /usr/bin/geoview)
	if ! bin_ok "$GEOVIEW"; then
		pkg_add geoview
		if ! bin_ok "$GEOVIEW"; then
			warn "geoview missing - sing-box cannot use geoip:/geosite: tags"
		fi
	fi
fi

# --- 3. optional geo source switch (downloads go through passwall2) -----
if [ "$GEO_SOURCE" = chocolate4u ]; then
	log "Switching geo source to Chocolate4U (has the full geosite:ir list)..."
	uci set $APP.@global_rules[0].geoip_url='https://raw.githubusercontent.com/Chocolate4U/Iran-v2ray-rules/release/geoip.dat'
	uci set $APP.@global_rules[0].geosite_url='https://raw.githubusercontent.com/Chocolate4U/Iran-v2ray-rules/release/geosite.dat'
	uci commit $APP
	COMMITTED=1
	if [ -f $APP_PATH/rule_update.lua ]; then
		lua $APP_PATH/rule_update.lua log all cron >/dev/null 2>&1 ||
			warn "geo download failed (offline?) - validation below keeps only tags the current data has"
	fi
fi

# --- 4. rules + node ----------------------------------------------------
log "Staging shunt rule and node..."

# Only our own sections are removed and rebuilt. passwall2's default rule names
# change between releases (China/CN, ProxyGame/DirectFront, ...), so a hard-coded
# "delete these" list breaks on the next version - and it is not needed: every
# rule we do not map on MainShunt is ignored (26.x filters shunt_rules by group,
# 25.12 only applies rules the node has an option for).
for s in MainShunt Iran; do
	uci -q delete "$APP.$s" 2>/dev/null || true
done

DOMAINS=$(cat <<'EOF'
geosite:ir
geosite:category-ir
geosite:category-bank-ir
geosite:category-news-ir
geosite:category-media-ir
geosite:category-tech-ir
geosite:category-shopping-ir
geosite:category-social-media-ir
geosite:category-gov-ir
geosite:category-ads-ir
geosite:category-finance
regexp:^.+\.ir$
kifpool.me
EOF
)

IPS=$(cat <<'EOF'
geoip:ir
0.0.0.0/8
10.0.0.0/8
100.64.0.0/10
127.0.0.0/8
169.254.0.0/16
172.16.0.0/12
192.0.0.0/24
192.0.2.0/24
192.88.99.0/24
192.168.0.0/16
198.19.0.0/16
198.51.100.0/24
203.0.113.0/24
224.0.0.0/4
240.0.0.0/4
255.255.255.255/32
::/128
::1/128
::ffff:0:0:0/96
64:ff9b::/96
100::/64
2001::/32
2001:20::/28
2001:db8::/32
2002::/16
fc00::/7
fe80::/10
ff00::/8
EOF
)

uci set $APP.Iran=shunt_rules
uci set $APP.Iran.remarks='Iran'
uci set $APP.Iran.network='tcp,udp'
uci set $APP.Iran.group='IR'
uci set $APP.Iran.domain_list="$DOMAINS"
uci set $APP.Iran.ip_list="$IPS"

uci set $APP.MainShunt=nodes
uci set $APP.MainShunt.remarks='Iran Shunt'
uci set $APP.MainShunt.type="$NODE_TYPE"
uci set $APP.MainShunt.protocol='_shunt'
uci set $APP.MainShunt.default_node="$DEF_NODE"
uci set $APP.MainShunt.domainStrategy='IPOnDemand'
uci set $APP.MainShunt.shunt_group='IR'
uci set $APP.MainShunt.write_ipset_direct='1'
uci set $APP.MainShunt.Iran='_direct'

uci set $APP.@global[0].node='MainShunt'
uci set $APP.@global[0].enabled='1'

# --- 5. validate geo tags with the real Xray binary ---------------------
if bin_ok "$XRAY_BIN"; then
	log "Validating geo tags against ${ASSET}geosite.dat / geoip.dat ..."
	attempt=0
	while :; do
		build_test_config > "$TEST_JSON"
		if xray_test "$TEST_JSON"; then
			log "Xray config test: PASSED"
			break
		fi
		code=$(sed -n 's/.*failed to \(check\|load\) code \([^ ]*\) from .*/\2/p' "$TEST_ERR" | head -n1)
		if [ -z "$code" ]; then
			log "Xray said:"
			sed -n '1,12p' "$TEST_ERR" | tee -a "$LOG"
			die "Xray rejected the test config (see above)"
		fi
		if NEW=$(printf '%s\n' "$DOMAINS" | awk -v c="$code" \
			'tolower($0) == "geosite:" tolower(c) { f = 1; next } { print } END { if (!f) exit 1 }'); then
			DOMAINS=$NEW
			PRUNED="$PRUNED geosite:$code"
			warn "geosite:$code is not in the installed geo data - dropped from the rule"
			attempt=$((attempt + 1))
			if [ "$attempt" -gt 4 ]; then
				log "Xray said:"
				sed -n '1,12p' "$TEST_ERR" | tee -a "$LOG"
				die "geo data still failing after dropping:$PRUNED"
			fi
			continue
		fi
		log "Xray said:"
		sed -n '1,12p' "$TEST_ERR" | tee -a "$LOG"
		die "geo code '$code' is missing and is required - geo data is incomplete"
	done
	# keep the pruned list in UCI as well
	uci set $APP.Iran.domain_list="$DOMAINS"
else
	warn "no Xray binary - skipping geo tag validation (sing-box ignores missing tags)"
fi

# --- 6. commit, start, verify -------------------------------------------
log "Committing changes..."
uci commit $APP
COMMITTED=1

log "Starting passwall2..."
/etc/init.d/$APP enable >/dev/null 2>&1 || true
/etc/init.d/$APP restart >/dev/null 2>&1 || true

if ! wait_core; then
	log "--- passwall2 log ---"
	logread -e passwall2 2>/dev/null | tail -n 25 | tee -a "$LOG" || true
	tail -n 25 /tmp/log/passwall2.log 2>/dev/null | tee -a "$LOG" || true
	die "the core process did not come up - rolling back"
fi

# keep a copy next to the config so it can be restored by hand after a reboot
cp -f /etc/config/$APP /etc/config/$APP.iranips.bak 2>/dev/null ||
	warn "could not write /etc/config/$APP.iranips.bak"

log "=== done ==="
log "core=$NODE_TYPE node=MainShunt default_node=$DEF_NODE rule=Iran (group IR, direct)"
if [ -n "$PRUNED" ]; then
	log "geo tags dropped (absent from installed data):$PRUNED"
fi
log "log: $LOG"
log "backup: /etc/config/$APP.iranips.bak (copy it back over /etc/config/$APP and restart passwall2 to undo)"
log "version: $VERSION"
log "RESULT: OK - Iranian traffic goes direct, everything else goes through '$DEF_NODE'."
exit 0
