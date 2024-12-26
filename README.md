# Zabbix-Agent-Install
Quick and siple script to install zabbix-agent to a host  

Usage example 
```
# ./zabbix-agent-install.sh --help
Usage: ./zabbix-agent-install.sh 
    --server <zabbix_server>    Server IP, separated with ", " for multi ip. Defaults to 10.10.10.10
    --port <zabbix_port>        Zabbix-agent listening port. Defaults to 10050
    --psk-enabled <0|1>         Enable psk, outputs psk settings at the end of the script. Defaults to 1.
    --agent-version <1|2>       Install zabbix-agent or zabbix-agent2. Defaults to zabbix-agent.
    --help			            Show this help message.
```
Run it with arguments.
```
# ./zabbix-agent-install.sh --server "10.10.10.10, fc00::10" --port 10050 --psk-enabled 1
```

Or download it with curl to bash.
```
# curl -s https://raw.githubusercontent.com/LeadSeason/Zabbix-Agent-Install/refs/heads/main/zabbix-agent-install.sh \
| bash -s -- --server "10.10.10.10, fc00::10"
```
