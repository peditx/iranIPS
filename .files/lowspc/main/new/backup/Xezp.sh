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

uci set system.@system[0].timezone='<+0330>-3:30'

uci commit

uci set system.@system[0].hostname='PeDitXrt'
uci commit system
/etc/init.d/system restart

/sbin/reload_config

cp ezp.sh /sbin/passwall

# First Reform
opkg update
opkg install curl luci-compat 
opkg install luci-lib-ipkg
sleep 2
clear
opkg install luci-app-ttyd
sleep 2
opkg remove uci-mod-dashboard
sleep 2

# GitHub repository URL and package name
REPO_URL="https://github.com/peditx/luci-theme-peditx"
LATEST_RELEASE_URL="https://api.github.com/repos/peditx/luci-theme-peditx/releases/latest"
IPK_URL=$(curl -s $LATEST_RELEASE_URL | grep "browser_download_url.*ipk" | cut -d '"' -f 4)

# Check if the download link is found
if [ -z "$IPK_URL" ]; then
  echo "Download link for the .ipk file not found."
  exit 1
fi

# Download the .ipk package
echo "Downloading the latest version of luci-theme-peditx..."
wget -q $IPK_URL -O /tmp/luci-theme-peditx.ipk

# Install the .ipk package
echo "Installing luci-theme-peditx..."
opkg install /tmp/luci-theme-peditx.ipk

# Clean up the downloaded file
rm /tmp/luci-theme-peditx.ipk

# Restart the web service to apply the changes
/etc/init.d/uhttpd restart


clear

echo -e "${GREEN}New theme Installed ✅ OK${NC}"
sleep 2
echo -e "${GREEN}Android mobile app service Installed ✅ OK${NC}"
sleep 2
echo -e "${GREEN}Ios native Web application Installed ✅ OK${NC}"
sleep 2
echo -e "${GREEN}New version of PeDitX theme Installed ✅ OK${NC}"
sleep 5


clear


##Scanning

. /etc/openwrt_release

echo -e "${MAGENTA} 
_______           _______  __   __     __    __            __          
|       \         |       \|  \ |  \   |  \  |  \          |  \         
| ▓▓▓▓▓▓▓\ ______ | ▓▓▓▓▓▓▓\\▓▓_| ▓▓_  | ▓▓  | ▓▓ ______  _| ▓▓_        
| ▓▓__/ ▓▓/      \| ▓▓  | ▓▓  \   ▓▓ \  \▓▓\/  ▓▓/      \|   ▓▓ \       
| ▓▓    ▓▓  ▓▓▓▓▓▓\ ▓▓  | ▓▓ ▓▓\▓▓▓▓▓▓   >▓▓  ▓▓|  ▓▓▓▓▓▓\\▓▓▓▓▓▓       
| ▓▓▓▓▓▓▓| ▓▓    ▓▓ ▓▓  | ▓▓ ▓▓ | ▓▓ __ /  ▓▓▓▓\| ▓▓   \▓▓ | ▓▓ __      
| ▓▓     | ▓▓▓▓▓▓▓▓ ▓▓__/ ▓▓ ▓▓ | ▓▓|  \  ▓▓ \▓▓\ ▓▓       | ▓▓|  \     
| ▓▓      \▓▓     \ ▓▓    ▓▓ ▓▓  \▓▓  ▓▓ ▓▓  | ▓▓ ▓▓        \▓▓  ▓▓     
 \▓▓       \▓▓▓▓▓▓▓\▓▓▓▓▓▓▓ \▓▓   \▓▓▓▓ \▓▓   \▓▓\▓▓         \▓▓▓▓      
                                      
                                                     P A S S W A L L ${NC}"
EPOL=`cat /tmp/sysinfo/model`
echo " - Model : $EPOL"
echo " - System Ver : $DISTRIB_RELEASE"
echo " - System Arch : $DISTRIB_ARCH"

# RESULT=`echo "$DISTRIB_RELEASE" | grep -o 23 | sed -n '1p'`

# if [ "$RESULT" == "23" ]; then


echo " "
RESULTT=`ls /etc/init.d/passwall 2>/dev/null`
if [ "$RESULTT" == "/etc/init.d/passwall" ]; then

echo -e "${YELLOW} > 4.${NC} ${GREEN} Update Your Passwall ${NC}"

 else
           
sleep 1

fi

RESULTTT=`ls /etc/init.d/passwall2 2>/dev/null`
if [ "$RESULTTT" == "/etc/init.d/passwall2" ]; then

echo -e "${YELLOW} > 5.${NC} ${GREEN} Update Your Passwall2 ${NC}"

 else
           
sleep 1

fi

echo -e "${GREEN} 1.${NC} ${CYAN} Install Passwall 1 ${NC}"
echo -e "${GREEN} 2.${NC} ${CYAN} Install Passwall 2 ${NC}"
echo -e "${GREEN} 3.${NC} ${BLUE} Install Passwall 1 + 2 ${NC}"
echo -e "${GREEN} 11.${NC} ${BLUE}Install Passwall 2 + Temporary core ${NC}"
echo -e "${GREEN} 6.${NC} ${MAGENTA} Easy Exroot For routers that have USB ${NC}"
echo -e "${GREEN} 7.${NC} ${RED} Extra tools ${NC}"
echo -e "${GREEN} 8.${NC} ${CYAN} Uninstall all Tools ${NC}"
echo -e "${YELLOW} 9.${NC} ${MAGENTA} CloudFlare IP Scanner ${NC}"
echo -e "${YELLOW} 10.${NC} ${YELLOW}Github/Sourceforge/OpenWrt Addresses Fixer ${NC}"
echo -e "${REF} 0.${NC} ${RED} EXIT ${NC}"
echo ""


echo " "
 read -p " -Select Passwall Option : " choice

    case $choice in

1)

echo "Installing Passwall 1 ..."

sleep 2

rm -f passwall.sh && wget https://github.com/peditx/iranIPS/raw/refs/heads/main/.files/passwall.sh && chmod 777 passwall.sh && sh passwall.sh


;;

2)
        
echo "Installing Passwall 2 ..."

sleep 2

rm -f passwall2.sh && wget https://github.com/peditx/iranIPS/raw/refs/heads/main/.files/passwall2.sh && chmod 777 passwall2.sh && sh passwall2.sh

 
;;

9)
        
echo "Installing CloudFlare IP SCAN ..."

opkg update

opkg install bash

opkg install curl

curl -ksSL https://gitlab.com/rwkgyg/cdnopw/raw/main/cdnopw.sh -o cdnopw.sh && bash cdnopw.sh
 
;;


4)
        
echo "Updating Passwall v1"

opkg update

opkg install luci-app-passwall

####improve

cd /tmp

wget -q https://github.com/peditx/iranIPS/raw/refs/heads/main/.files/hard.zip

unzip -o hard.zip -d /

cd

########
 
;;


5)
        
echo "Updating Passwall v2"

opkg update

opkg install luci-app-passwall2

####improve

cd /tmp

wget -q https://github.com/peditx/iranIPS/raw/refs/heads/main/.files/hard.zip

unzip -o hard.zip -d /

cd

########

;;


0)
            echo ""
            echo -e "${GREEN}Exiting...${NC}"
            exit 0

           read -s -n 1
           ;;

6)
        
echo "Easy Exroot Openwrt For routers that have USB ..."

opkg update

opkg install bash

opkg install curl

curl -ksSL https://github.com/peditx/ezexroot/raw/refs/heads/main/ezexroot.sh -o ezexroot.sh && bash ezexroot.sh
 
;;

7)
        
echo "Extra Tools (Wifi settings and cleanup memory) ..."

curl -ksSL https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/extras/extra.sh -o extra.sh && bash extra.sh
 
;;

8)
        
echo "Uninstall tools ..."

curl -ksSL https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/core/uninstall.sh -o uninstall.sh && bash uninstall.sh
 
;;

10)
        
echo "Github/Sourceforge/OpenWrt Addresses Fix ..."

curl -ksSL https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/host.sh -o host.sh && bash host.sh
 
;;


 3)

echo "Installing Passwall 1 and 2 ..."

sleep 2

rm -f passwalldue.sh && wget https://github.com/peditx/iranIPS/raw/refs/heads/main/.files/passwalldue.sh && chmod 777 passwalldue.sh && sh passwalldue.sh


;;

11)

echo "Installing Passwall 2 With Temporary Core ..."

sleep 2

rm -f tempcore.sh && wget https://raw.githubusercontent.com/peditx/iranIPS/refs/heads/main/.files/core/tempcore.sh && chmod 777 tempcore.sh && sh tempcore.sh


;;

 *)
           echo "  Invalid option Selected ! "
           echo " "
           echo -e "  Press ${RED}ENTER${NC} to continue"
           exit 0
           read -s -n 1
           ;;
      esac
