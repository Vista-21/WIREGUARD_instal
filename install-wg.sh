#!/bin/bash

set -e

REPO="https://raw.githubusercontent.com/Vista-21/WIREGUARD_instal/main"

echo "Updating system..."
apt update

echo "Checking nano..."
if ! command -v nano >/dev/null 2>&1; then
    apt install -y nano
fi

echo "Installing WireGuard..."
apt install -y wireguard iptables curl

mkdir -p /etc/wireguard
mkdir -p ~/wg-clients

echo "Downloading management scripts..."
curl -s -o /usr/local/bin/wg-add-client     $REPO/wg-add-client.sh
curl -s -o /usr/local/bin/wg-del-client     $REPO/wg-del-client.sh
curl -s -o /usr/local/bin/wg-peers          $REPO/wg-peers.sh
curl -s -o /usr/local/bin/wg-clean          $REPO/wg-clean.sh

chmod +x /usr/local/bin/wg-*

echo "Generating server keys..."
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key

SERVER_PRIV=$(cat /etc/wireguard/server_private.key)
SERVER_PUB=$(cat /etc/wireguard/server_public.key)

SERVER_PORT=37821
SERVER_IP="10.8.0.1/24"
MTU=1280
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')

echo "Creating wg0.conf..."
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = $SERVER_IP
ListenPort = $SERVER_PORT
PrivateKey = $SERVER_PRIV
MTU = $MTU
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $IFACE -j MASQUERADE
EOF

echo "Creating default clients..."
wg-add-client main_test
wg-add-client user_test#1
wg-add-client user_test#2

chmod 600 /etc/wireguard/wg0.conf
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

echo "WireGuard installation complete."
echo "Clients are in: ~/wg-clients/"
echo "Commands: wg-add-client, wg-del-client, wg-peers, wg-clean"
