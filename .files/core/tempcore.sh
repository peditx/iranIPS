#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo "Running as root..."
sleep 2
clear

uci set system.@system[0].zonename='Asia/Tehran'

uci set network.wan.peerdns="0"

uci set network.wan6.peerdns="0"

uci set network.wan.dns='1.1.1.1'

uci set network.wan6.dns='2001:4860:4860::8888'

uci set system.@system[0].timezone='<+0330>-3:30'

uci commit system

uci commit network

uci commit

/sbin/reload_config

SNNAP=`grep -o SNAPSHOT /etc/openwrt_release | sed -n '1p'`

if [ "$SNNAP" == "SNAPSHOT" ]; then

echo -e "${YELLOW} SNAPSHOT Version Detected ! ${NC}"

rm -f core.sh && wget https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/core/core.sh && chmod 777 core.sh && sh core.sh

exit 1

 else
           
echo -e "${GREEN} Updating Packages ... ${NC}"

fi

### Update Packages ###

opkg update

### Add Src ###

wget -O passwall.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub

opkg-key add passwall.pub

>/etc/opkg/customfeeds.conf

read release arch << EOF
$(. /etc/openwrt_release ; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF
for feed in passwall_luci passwall_packages passwall2; do
  echo "src/gz $feed https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/$feed" >> /etc/opkg/customfeeds.conf
done

### Install package ###

opkg update
sleep 3
opkg remove dnsmasq
sleep 3
opkg install dnsmasq-full
sleep 2
opkg install unzip
sleep 2
opkg install luci-app-passwall2
sleep 3
opkg install kmod-nft-socket
sleep 2
opkg install kmod-nft-tproxy
sleep 2
opkg install ca-bundle
sleep 1
opkg install kmod-inet-diag
sleep 1
opkg install kernel
sleep 1
opkg install kmod-netlink-diag
sleep 1
opkg install kmod-tun
opkg install v2ray-geosite-ir
sleep 2

>/etc/banner

echo " _______           _______  __   __     __    __            __          
|       \         |       \|  \ |  \   |  \  |  \          |  \         
| ▓▓▓▓▓▓▓\ ______ | ▓▓▓▓▓▓▓\\▓▓_| ▓▓_  | ▓▓  | ▓▓ ______  _| ▓▓_        
| ▓▓__/ ▓▓/      \| ▓▓  | ▓▓  \   ▓▓ \  \▓▓\/  ▓▓/      \|   ▓▓ \       
| ▓▓    ▓▓  ▓▓▓▓▓▓\ ▓▓  | ▓▓ ▓▓\▓▓▓▓▓▓   >▓▓  ▓▓|  ▓▓▓▓▓▓\\▓▓▓▓▓▓       
| ▓▓▓▓▓▓▓| ▓▓    ▓▓ ▓▓  | ▓▓ ▓▓ | ▓▓ __ /  ▓▓▓▓\| ▓▓   \▓▓ | ▓▓ __      
| ▓▓     | ▓▓▓▓▓▓▓▓ ▓▓__/ ▓▓ ▓▓ | ▓▓|  \  ▓▓ \▓▓\ ▓▓       | ▓▓|  \     
| ▓▓      \▓▓     \ ▓▓    ▓▓ ▓▓  \▓▓  ▓▓ ▓▓  | ▓▓ ▓▓        \▓▓  ▓▓     
 \▓▓       \▓▓▓▓▓▓▓\▓▓▓▓▓▓▓ \▓▓   \▓▓▓▓ \▓▓   \▓▓\▓▓         \▓▓▓▓      
                                      
                                                     P A S S W A L L                                                                                         
telegram : @PeDitX" >> /etc/banner

sleep 1

RESULT5=`ls /etc/init.d/passwall2`

if [ "$RESULT5" == "/etc/init.d/passwall2" ]; then

echo -e "${GREEN} Passwall.2 Installed Successfully ! ${NC}"

 else

 echo -e "${RED} Can not Download Packages ... Check your internet Connection . ${NC}"

 exit 1

fi


DNS=`ls /usr/lib/opkg/info/dnsmasq-full.control`

if [ "$DNS" == "/usr/lib/opkg/info/dnsmasq-full.control" ]; then

echo -e "${GREEN} dnsmaq-full Installed successfully ! ${NC}"

 else
           
echo -e "${RED} Package : dnsmasq-full not installed ! (Bad internet connection .) ${NC}"

exit 1

fi

####install_xray
opkg install xray-core

sleep 2

RESULT=`ls /usr/bin/xray`

if [ "$RESULT" == "/usr/bin/xray" ]; then

echo -e "${GREEN} XRAY : OK ! ${NC}"

 else

 echo -e "${YELLOW} XRAY : NOT INSTALLED X ${NC}"

 sleep 2
 
 echo -e "${YELLOW} Trying to install Xray on temp Space ... ${NC}"

 sleep 2
  
rm -f pedscript.sh && wget https://github.com/peditx/iranIPS/raw/refs/heads/main/.files/lowspc/pedscript.sh && chmod 777 pedscript.sh && sh pedscript.sh

fi


####improve

cd /tmp

wget -q https://github.com/peditx/iranIPS/raw/refs/heads/main/.files/hard.zip

unzip -o hard.zip -d /

cd

#########

uci set passwall2.@global_forwarding[0]=global_forwarding
uci set passwall2.@global_forwarding[0].tcp_no_redir_ports='disable'
uci set passwall2.@global_forwarding[0].udp_no_redir_ports='disable'
uci set passwall2.@global_forwarding[0].tcp_redir_ports='1:65535'
uci set passwall2.@global_forwarding[0].udp_redir_ports='1:65535'
uci set passwall2.@global[0].remote_dns='8.8.4.4'

# Delete unused rules
uci delete passwall2.ProxyGame
uci delete passwall2.GooglePlay
uci delete passwall2.Netflix
uci delete passwall2.OpenAI
uci delete passwall2.Proxy
uci delete passwall2.China
uci delete passwall2.QUIC
uci delete passwall2.UDP

uci set passwall2.Direct=shunt_rules
uci set passwall2.Direct.network='tcp,udp'
uci set passwall2.Direct.remarks='IRAN'
uci set passwall2.Direct.ip_list='geoip:ir
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
ff00::/8'
uci set passwall2.Direct.domain_list='regexp:^.+\.ir$
geosite:category-ir
kifpool.me'
###pcdirect
uci set passwall2.DirectGame=shunt_rules
uci set passwall2.DirectGame.network='tcp,udp'
uci set passwall2.DirectGame.remarks='PC-Direct'
uci set passwall2.DirectGame.ip_list=''  # لیست IP خالی
uci set passwall2.DirectGame.domain_list='nvidia.com
youtube.com
epicgames.com
meta.com
instagram.com
facebook.com
twitter.com
tiktok.com
spotify.com
capcut.com
adobe.com
ubisoft.com
google.com
x.com
bingx.com
mexc.com
openwrt.org
twitch.tv
asus.com
byteoversea.com
tiktokv.com
xbox.com
us.download.nvidia.com
fcdn.co
adobe.io
cloudflare.com
playstation.com
tradingview.com
reachthefinals.com
midi-mixer.com
google-analytics.com
cloudflare-dns.com
bingx.com
activision.com
biostar.com.tw
aternos.me
geforce.com
gvt1.com
ubi.com
ea.com
eapressportal.com
myaccount.ea.com
origin.com
epicgames.dev
rockstargames.com
rockstarnorth.com
googlevideo.com
2ip.io
telegram.com
telegram.org
safepal.com
microsoft.com
apps.microsoft.com
live.com
ytimg.com
t.me
whatsapp.com
reddit.com
pvp.net
discord.com
discord.gg
discordapp.net
discordapp.com
bing.com
discord.media
approved-proxy.bc.ubisoft.com
tlauncher.org
aternos.host
aternos.me
aternos.org
aternos.net
aternos.com
steamcommunity.com
steam.com
steampowered.com
steamstatic.com
chatgpt.com
openai.com'
#####pcdirect end

uci set passwall2.myshunt.Direct='_direct'
###pcdirect set
uci set passwall2.myshunt.DirectGame='_direct'
#  myshunt
uci delete passwall2.myshunt

#  MainShunt
uci set passwall2.MainShunt=nodes
uci set passwall2.MainShunt.remarks='MainShunt'
uci set passwall2.MainShunt.type='Xray'
uci set passwall2.MainShunt.protocol='_shunt'
uci set passwall2.MainShunt.Direct='_direct'
uci set passwall2.MainShunt.DirectGame='_default'

# PC-Shunt
uci set passwall2.PC_Shunt=nodes
uci set passwall2.PC_Shunt.remarks='PC-Shunt'
uci set passwall2.PC_Shunt.type='Xray'
uci set passwall2.PC_Shunt.protocol='_shunt'
uci set passwall2.PC_Shunt.Direct='_direct'
uci set passwall2.PC_Shunt.DirectGame='_default'

uci commit passwall2

uci commit system

sed -i 's/XTLS\/Xray-core/GFW-knocker\/Xray-core/g' /usr/lib/lua/luci/passwall2/com.lua

uci set system.@system[0].hostname=PeDitXrt

uci commit system

uci commit network

uci commit wireless

uci set dhcp.@dnsmasq[0].rebind_domain='www.ebanksepah.ir 
my.irancell.ir'

uci commit

uci commit

rm /usr/bin/xray

echo -e "${YELLOW}** Warning : To install Mahsa Core visit > Passwall2 > App Update > Xray Force Update ** ${ENDCOLOR}"

echo -e "${MAGENTA} Made By : PeDitX ${ENDCOLOR}"

rm passwall2.sh

rm tempcore.sh

/sbin/reload_config

/etc/init.d/network reload
