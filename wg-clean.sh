#!/bin/bash

echo "Stopping WireGuard..."
systemctl stop wg-quick@wg0 2>/dev/null
systemctl disable wg-quick@wg0 2>/dev/null

echo "Removing iptables rules..."
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
iptables -D FORWARD -i wg0 -j ACCEPT 2>/dev/null
iptables -D FORWARD -o wg0 -j ACCEPT 2>/dev/null
iptables -t nat -D POSTROUTING -o $IFACE -j MASQUERADE 2>/dev/null

echo "Removing configs and keys..."
rm -rf /etc/wireguard
rm -rf ~/wg-clients

echo "Removing packages..."
apt remove -y wireguard wireguard-tools 2>/dev/null
apt autoremove -y 2>/dev/null

ip link del wg0 2>/dev/null

echo "WireGuard fully removed."
