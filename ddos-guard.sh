#!/bin/bash

# Anti DDoS and Fail2Ban Setup Script for Ubuntu 22.04 LTS on DigitalOcean
# Author: @purwowd

clear_rules() {
    echo "[+] Clearing existing iptables rules..."
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
}

setup_antiddos_rules() {
    echo "[+] Setting up iptables rules for anti-DDoS protection..."

    # Drop invalid packets
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    iptables -A FORWARD -m conntrack --ctstate INVALID -j DROP

    # SYN flood protection (limit the number of SYN packets)
    iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 4 -j ACCEPT

    # Limit new connections (prevent high rate of new connections)
    iptables -A INPUT -p tcp -m conntrack --ctstate NEW -m limit --limit 50/s --limit-burst 20 -j ACCEPT
    iptables -A INPUT -p tcp -m conntrack --ctstate NEW -j DROP

    # Limit ICMP requests (ping flood protection)
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 10 -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

    # Drop excessive RST packets (protection against TCP RST flood)
    iptables -A INPUT -p tcp --tcp-flags RST RST -m limit --limit 2/s --limit-burst 2 -j ACCEPT
    iptables -A INPUT -p tcp --tcp-flags RST RST -j DROP

    # UDP flood protection (LOIC often uses UDP flood)
    iptables -A INPUT -p udp -m limit --limit 10/s --limit-burst 20 -j ACCEPT
    iptables -A INPUT -p udp -j DROP

    # HTTP flood protection (limit HTTP requests per second)
    iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 100 -j REJECT
    iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 100 -j REJECT

    # Allow established and related traffic
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Allow traffic on specific ports (adjust for your server needs)
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT   # SSH
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT   # HTTP
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT  # HTTPS

    # Log and drop excess traffic (optional, for monitoring purposes)
    iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "DDoS attack: " --log-level 7
    iptables -A INPUT -j DROP

    echo "[+] Anti-DDoS rules applied."
}

setup_fail2ban() {
    echo "[+] Installing Fail2Ban..."
    apt install -y fail2ban

    echo "[+] Configuring Fail2Ban..."

    cat <<EOT > /etc/fail2ban/jail.local
[DEFAULT]
bantime  = 1h
findtime  = 10m
maxretry = 3
destemail = digitalocean.id@gmail.com
sender = fail2ban@example.com
mta = sendmail
action = %(action_mwl)s

[sshd]
enabled = true
port    = ssh
logpath = /var/log/auth.log
maxretry = 3

[http-get-dos]
enabled = true
filter = http-get-dos
action = iptables[name=HTTP, port=http, protocol=tcp]
logpath = /var/log/apache2/access.log
maxretry = 10
findtime = 10
bantime = 3600
EOT

    cat <<EOT > /etc/fail2ban/filter.d/http-get-dos.conf
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*
ignoreregex =
EOT

    echo "[+] Restarting Fail2Ban service..."
    systemctl restart fail2ban
    systemctl enable fail2ban

    echo "[+] Fail2Ban is active."
}

# Function to set up UFW firewall (optional but recommended on DigitalOcean)
setup_ufw() {
    echo "[+] Configuring UFW firewall..."
    apt install -y ufw
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow http
    ufw allow https
    ufw enable
    echo "[+] UFW firewall configured and enabled."
}

echo "Anti-DDoS, Fail2Ban, and UFW Setup Script for DigitalOcean Started"
clear_rules
setup_antiddos_rules
setup_fail2ban
setup_ufw
