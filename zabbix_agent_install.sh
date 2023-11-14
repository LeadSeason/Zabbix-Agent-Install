#!/bin/env bash

DebianBased() {
    echo "Debian based distrobution detected."
    apt-get update -y
    apt-get install zabbix-agent || exit 11
}

ArchBased() {
    echo "Arch based distrobution detected."
    pacman -Syu --noconfirm zabbix-agent || exit 11
}

if [ "$(id -u)" -ne 0 ]; then
    echo "Insufficient permissions."
    exit 10
fi

zabbixIP="10.50.0.15"
echo "Zabbix address 10.50.0.15"

agent_config="# This is a configuration file for Zabbix agent daemon (Unix)
PidFile=/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix-agent/zabbix_agentd.log
LogFileSize=0

Server=$zabbixIP
ListenPort=10050

ServerActive=127.0.0.1

Include=/etc/zabbix/zabbix_agentd.conf.d/*.conf
"

echo "Installing Zabbix"
case "$(lsb_release -is)" in
    "Ubuntu" | "Debian" | "Vyos") DebianBased;;
    "Arch") ArchBased;;
    *) echo "Your distribution \"$(lsb_release  -is) $(lsb_release  -rs)\" is not supported." && exit 12;;
esac

echo "Enabaling Zabbix at boot."
systemctl enable zabbix-agent
echo "\033[0;32mDONE"

echo -n "Installing configuration ..."
mv /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf.old
echo "$agent_config" > /etc/zabbix/zabbix_agentd.conf
echo "\033[0;32mDONE"

echo -n "Restaring Zabbix agent ... "
systemctl restart zabbix-agent
echo "\033[0;32mDONE"

ip=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
hostname=$(cat /etc/hostname)

echo "The Zabbix agent has been installed and configured. Your primary IP is $ip and the hostname is $hostname"
