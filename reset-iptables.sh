#!/bin/bash

# Clear all iptables rules
echo "[+] Resetting iptables rules..."
iptables -F    # Flush all rules
iptables -X    # Delete all custom chains
iptables -t nat -F   # Flush nat table
iptables -t nat -X   # Delete nat table chains
iptables -t mangle -F   # Flush mangle table
iptables -t mangle -X   # Delete mangle table chains
iptables -P INPUT ACCEPT   # Set default policy to ACCEPT for INPUT chain
iptables -P FORWARD ACCEPT # Set default policy to ACCEPT for FORWARD chain
iptables -P OUTPUT ACCEPT  # Set default policy to ACCEPT for OUTPUT chain
echo "[+] iptables rules have been reset."
