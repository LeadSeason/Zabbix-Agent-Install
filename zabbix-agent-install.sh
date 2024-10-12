#!/bin/bash

set -e

# Check root permissions
if [ "$(id -u)" -ne 0 ]; then
    echo "Insufficient permissions."
    exit 10
fi

# Default values
ZABBIX_SERVER="10.10.10.10"
ZABBIX_PORT="10050"
ZABBIX_PKS_ENABLED=1

ZABBIX_CONF_LOCATION="/etc/zabbix/zabbix_agentd.conf"
ZABBIX_CONF_DIR_LOCATION="/etc/zabbix/"
ZABBIX_LOG_LOCATION="/var/log/zabbix/zabbix_agentd.log"
ZABBIX_LOG_DIR_LOCATION="/var/log/zabbix/"
ZABBIX_PID_LOCATION="/run/zabbix/zabbix_agentd.pid"
ZABBIX_USER_NAME="zabbix"

SYSTEM_DISTRO=$(awk -F= '$1 == "ID" {print $2}' /etc/os-release)
SYSTEM_IP=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([^ ]*\).*/\1/p')
SYSTEM_IPV6=$(ip -o route get to 2001:4860:4860::8888 | sed -n 's/.*src \([^ ]*\).*/\1/p')
SYSTEM_HOSTNAME=$(cat /etc/hostname)

# Argument handeling
usage() {
    printf "%s\n" "Usage: $0 
    --server <zabbix_server>    Server IP, seporated with \", \" for multi ip. Defaults to 10.10.10.10
    --port <zabbix_port>        Zabbix-agent listening port. Defaults to 10050
    --psk-enabled <0|1>         Enable psk, outputs psk settings at the end of the script. Defaults to 1.
"
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --server)
            ZABBIX_SERVER="$2"
            shift 2
            ;;
        --port)
            ZABBIX_PORT="$2"
            shift 2
            ;;
        --psk-enabled)
            ZABBIX_PKS_ENABLED="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            ;;
    esac
done

echo "Zabbix Server: $ZABBIX_SERVER"
echo "Zabbix Port: $ZABBIX_PORT"
echo "PSK Enabled: $ZABBIX_PKS_ENABLED"

# Install Zabbix-agent
# Ubuntu
if [ "$SYSTEM_DISTRO" = "Ubuntu" ]; then
	echo "Ubuntu detected, continuing with install."
	
	# Ubuntu doesnt provide Zabbix-agent, so we need to install zabbix official repos
	UBUNTUTMP=$(lsb_release -r)
	UBUNTUTMP2=$(cut -f2 <<< "$UBUNTUTMP")
	UBUNTU_VERSION_FILE="zabbix-release_7.0-2+ubuntu${UBUNTUTMP2}_all.deb"
	
	wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/$UBUNTU_VERSION_FILE -o /tmp/$UBUNTU_VERSION_FILE
	dpkg -i /tmp/$UBUNTU_VERSION_FILE 
	
	apt-get update -y
	apt-get install zabbix-agent -y || exit 11

# Debian
elif [ "$SYSTEM_DISTRO" = "debian" ]; then
	echo "Debian detected, continuing with install."

	apt-get update -y > /dev/null
	apt-get install zabbix-agent -y > /dev/null

# ArchLinux
elif [ "$SYSTEM_DISTRO" = "Arch" ]; then
	# We do not know what state the arch is so we force upgrade.
	echo "Arch based distribution detected."
	echo "Warning fully upgradeing before installing"
	echo "Press Enter to continue. Press Ctrl + c to cancel."
	read || exit 13

 	# @TODO
  	# Zabbix has diffrent dirrectorys for logs. Add later.
 	
	pacman -Sy --noconfirm archlinux-keyring || exit 11
	pacman -Syu --noconfirm || exit 11
	pacman -S --noconfirm zabbix-agent || exit 11

# CentOS
elif [ "$SYSTEM_DISTRO" = "centos" ]; then
	echo "CentOS detected, continuing with install."
	
	# For some reason Zabbix-agent will not work with pks on rhel based systems
	ZABBIX_PKS_ENABLED=0
	ZABBIX_CONF_LOCATION="/etc/zabbix_agentd.conf"
	
	yum install -y zabbix-agent

# RockyLinux
elif [ "$SYSTEM_DISTRO" = "\"rocky\"" ]; then
	echo "Rocky detected, continuing with install."

 	# For some reason Zabbix-agent will not work with pks on rhel based systems
	ZABBIX_PKS_ENABLED=0
	ZABBIX_CONF_LOCATION="/etc/zabbix_agentd.conf"
	
	yum install -y zabbix-agent

# Default
else
	echo "Your distribution \"$(lsb_release  -is) $(lsb_release  -rs)\" is not supported."
	exit 12
fi

# Configuration
ZABBIX_AGENT_CONFIGURATION="# This is a configuration file for Zabbix agent daemon (Unix)
PidFile=$ZABBIX_PID_LOCATION
LogFile=$ZABBIX_LOG_LOCATION

Server=$ZABBIX_SERVER
ListenPort=$ZABBIX_PORT

ServerActive=127.0.0.1

Include=/etc/zabbix/zabbix_agentd.d/*.conf

"

# Enable at boot
echo "Enabaling Zabbix at boot ..."
systemctl enable zabbix-agent

# Configuration install
echo "Installing configuration ..."
mkdir -p /etc/zabbix/zabbix_agentd.d/
chown $ZABBIX_USER_NAME:$ZABBIX_USER_NAME /etc/zabbix/zabbix_agentd.d/

# Log dir
mkdir -p $ZABBIX_LOG_DIR_LOCATION
chown $ZABBIX_USER_NAME:$ZABBIX_USER_NAME $ZABBIX_LOG_DIR_LOCATION

# Backup old zabbix configuration
mv $ZABBIX_CONF_LOCATION "$ZABBIX_CONF_LOCATION".old
touch $ZABBIX_CONF_LOCATION
chown $ZABBIX_USER_NAME:$ZABBIX_USER_NAME $ZABBIX_CONF_LOCATION

# Install configuration
echo "$ZABBIX_AGENT_CONFIGURATION" > $ZABBIX_CONF_LOCATION

if [ "$ZABBIX_PKS_ENABLED" -ne 0 ]; then
	# PSK install
	ZABBIX_PSK=$(openssl rand -hex 32 | tee /etc/zabbix/zabbix_agentd.psk)
	chown $ZABBIX_USER_NAME:$ZABBIX_USER_NAME /etc/zabbix/zabbix_agentd.psk
	chmod 400 /etc/zabbix/zabbix_agentd.psk

	ZABBIX_PKS_CONFIGUARION="# Zabbix PSK
TLSConnect=psk
TLSAccept=psk
TLSPSKFile=/etc/zabbix/zabbix_agentd.psk
TLSPSKIdentity=PSK-$SYSTEM_HOSTNAME
" 
	printf "%s\n" "$ZABBIX_PKS_CONFIGUARION" >> "$ZABBIX_CONF_LOCATION"
fi

# Restart Zabbix
echo "Restaring Zabbix agent ..."
systemctl restart zabbix-agent

# Allow Zabbix in
# UFW
if command -v ufw >/dev/null; then
	IFS=', '
	for IP in $ZABBIX_SERVER; do
		echo "Allow zabbix ($IP) through firewall. UFW"
		ufw allow from $IP to any port $ZABBIX_PORT comment "Allow zabbix-agent"
 	done

# FirewallD
elif command -v firewall-cmd >/dev/null; then
	# Yeah, this could be better.
	echo "Allow zabbix through firewall. FirewallD"
	firewall-cmd --zone=public --add-service=zabbix-agent --permanent
	firewall-cmd --reload
fi

# Final Message
echo "###########################"
if [ "$ZABBIX_PKS_ENABLED" -ne 0 ]; then
	echo "Enter the Next PSK identity and Key in to Zabbix."
	echo "Zabbix PSK ID: PSK-$SYSTEM_HOSTNAME"
	echo "Zabbix PSK   : $ZABBIX_PSK"
fi
echo "The Zabbix agent has been installed and configured. Your primary IP is $SYSTEM_IP, $SYSTEM_IPV6 and the hostname is $SYSTEM_HOSTNAME"
exit 0
