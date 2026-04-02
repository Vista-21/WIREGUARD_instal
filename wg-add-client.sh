#!/bin/bash
set -e

CLIENTS_DIR="${HOME}/wg-clients"
WG_CONF="/etc/wireguard/wg0.conf"
SERVER_IP_NET="10.8.0.0/24"

if [ -z "$1" ]; then
  echo "Usage: wg-add-client <name>"
  exit 1
fi

NAME="$1"
CLIENT_CONF="${CLIENTS_DIR}/${NAME}.conf"

if [ -f "$CLIENT_CONF" ]; then
  echo "Client ${NAME} already exists: $CLIENT_CONF"
  exit 1
fi

mkdir -p "$CLIENTS_DIR"

# Генерация ключей
CLIENT_PRIV=$(wg genkey)
CLIENT_PUB=$(echo "$CLIENT_PRIV" | wg pubkey)
PRESHARED_KEY=$(wg genpsk)

# Определение следующего IP
LAST_IP=$(grep -oP '10\.8\.0\.\d+' "$WG_CONF" | sort -t. -k4 -n | tail -n1 | awk -F. '{print $4}')
NEXT_IP=$((LAST_IP+1))
CLIENT_IP="10.8.0.${NEXT_IP}/32"

SERVER_PUB=$(grep -oP '(?<=^PublicKey = ).+' "$WG_CONF" | head -n1)
SERVER_ENDPOINT_PORT=$(grep -oP '(?<=^ListenPort = )\d+' "$WG_CONF")
SERVER_ENDPOINT_HOST=$(hostname -I | awk '{print $1}')

# Добавляем peer в wg0.conf
cat >> "$WG_CONF" <<EOF

[Peer]
# $NAME
PublicKey = $CLIENT_PUB
PresharedKey = $PRESHARED_KEY
AllowedIPs = ${CLIENT_IP}
EOF

# Конфиг клиента
cat > "$CLIENT_CONF" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIV
Address = $CLIENT_IP
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB
PresharedKey = $PRESHARED_KEY
Endpoint = ${SERVER_ENDPOINT_HOST}:${SERVER_ENDPOINT_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

chmod 600 "$CLIENT_CONF"

systemctl restart wg-quick@wg0

echo "Client created: $CLIENT_CONF"
