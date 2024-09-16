#!/usr/bin/env bash

ZABBIX_SERVER="10.10.10.10"

SYSTEM_DISTRO=$(awk -F= '$1 == "ID" {print $2}' /etc/os-release)
SYSTEM_IP=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
SYSTEM_HOSTNAME=$(cat /etc/hostname)

# Debian based distribution install.
DebianBased() {
    echo "Debian based distribution detected."
    apt-get update -y
    apt-get install -y zabbix-agent || exit 11
}

# Archlinux based distribution install.
ArchBased() {
    echo "Arch based distribution detected."
	echo "Warning fully upgradeing before installing"
	echo "Press Enter to continue. Press Ctrl + c to cancel."
	read || exit 13
    pacman -Sy --noconfirm archlinux-keyring || exit 11
	pacman -Syu --noconfirm || exit 11
	pacman -S --noconfirm zabbix-agent || exit 11
}

# Redhat based distribution install.
REHLBased() {
	echo "RHEL based distribution detected."
	yum install -y zabbix-agent
}

if [ "$(id -u)" -ne 0 ]; then
    echo "Insufficient permissions."
    exit 10
fi

echo "Zabbix server address: $ZABBIX_SERVER"

# Configuration
ZABBIX_AGENT_CONFIGURATION="# This is a configuration file for Zabbix agent daemon (Unix)
PidFile=/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix-agent/zabbix_agentd.log

DenyKey=system.run[*]

Server=$ZABBIX_SERVER
ListenPort=10050

ServerActive=127.0.0.1

Include=/etc/zabbix/zabbix_agentd.conf.d/*.conf

# Zabbix PSK
TLSConnect=psk
TLSAccept=psk
TLSPSKFile=/etc/zabbix/zabbix_agentd.psk
TLSPSKIdentity=PSK-$SYSTEM_HOSTNAME
"

# Install Zabbix-agent
echo "Installing Zabbix ..."
case "$SYSTEM_DISTRO" in
    "ubuntu" | "debian" | "vyos") DebianBased;;
    "arch") ArchBased;;
	"centos" | "rocky") REHLBased;;
    *) echo "Your distribution \"$SYSTEM_DISTRO\" is not supported." && exit 12;;
esac

# Enable at boot
echo "Enabaling Zabbix at boot ..."
systemctl enable zabbix-agent

# Install configuration
echo -n "Installing configuration ..."
mv /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf.old
echo "$ZABBIX_AGENT_CONFIGURATION" > /etc/zabbix/zabbix_agentd.conf

# PSK install
ZABBIX_PSK=$(openssl rand -hex 32 | tee /etc/zabbix/zabbix_agentd.psk)
chown zabbix:zabbix /etc/zabbix/zabbix_agentd.psk
chmod 400 /etc/zabbix/zabbix_agentd.psk

# Restart Zabbix
echo "Restaring Zabbix agent ..."
systemctl restart zabbix-agent

# Final Message
echo "Enter the Next PSK identity and Key in to Zabbix."
echo "Zabbix PSK ID: PSK-$SYSTEM_HOSTNAME"
echo "Zabbix PSK   : $ZABBIX_PSK"
echo "The Zabbix agent has been installed and configured. Your primary IP is $SYSTEM_IP and the hostname is $SYSTEM_HOSTNAME"

exit 0
