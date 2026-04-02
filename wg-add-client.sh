#!/bin/bash

NAME="$1"
IP_BASE="10.8.0."
MTU=1280
SERVER_PUB=$(cat /etc/wireguard/server_public.key)
SERVER_PORT=37821
SERVER_IP=$(curl -4 -s ifconfig.me)

if [ -z "$NAME" ]; then
    echo "Usage: wg-add-client <client_name>"
    exit 1
fi

LAST=$(grep AllowedIPs /etc/wireguard/wg0.conf | awk -F'[ ./]' '{print $6}' | sort -n | tail -1)
if [ -z "$LAST" ]; then LAST=1; fi
NEXT=$((LAST+1))
IP="${IP_BASE}${NEXT}"

wg genkey | tee /etc/wireguard/${NAME}_private.key | wg pubkey > /etc/wireguard/${NAME}_public.key

PRIV=$(cat /etc/wireguard/${NAME}_private.key)
PUB=$(cat /etc/wireguard/${NAME}_public.key)

cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
PublicKey = $PUB
AllowedIPs = $IP/32
EOF

mkdir -p ~/wg-clients
cat > ~/wg-clients/${NAME}.conf <<EOF
[Interface]
PrivateKey = $PRIV
Address = $IP/32
DNS = 8.8.8.8
MTU = $MTU

[Peer]
PublicKey = $SERVER_PUB
Endpoint = ${SERVER_IP}:$SERVER_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 0
EOF

systemctl restart wg-quick@wg0
echo "Client created: ~/wg-clients/${NAME}.conf"
