#!/bin/bash
set -e

CLIENTS_DIR="${HOME}/wg-clients"
WG_CONF="/etc/wireguard/wg0.conf"

if [ -z "$1" ]; then
  echo "Usage: wg-del-client <name>"
  exit 1
fi

NAME="$1"
CLIENT_CONF="${CLIENTS_DIR}/${NAME}.conf"

if [ ! -f "$CLIENT_CONF" ]; then
  echo "Client config not found: $CLIENT_CONF"
fi

# Находим PublicKey клиента
CLIENT_PUB=$(grep -A5 "

\[Peer\]

" "$WG_CONF" | grep -B5 -A5 "$NAME" | grep -oP '(?<=PublicKey = ).+' | head -n1)

if [ -z "$CLIENT_PUB" ]; then
  # fallback: по ключу из конфига клиента
  CLIENT_PUB=$(grep -oP '(?<=PublicKey = ).+' "$CLIENT_CONF" 2>/dev/null || true)
fi

if [ -z "$CLIENT_PUB" ]; then
  echo "Cannot find client PublicKey for $NAME in $WG_CONF"
else
  # Удаляем блок [Peer] по PublicKey
  awk -v key="$CLIENT_PUB" '
    BEGIN {skip=0}
    /^

\[Peer\]

/ {block_start=NR}
    {
      if (skip && NR>block_start && NF==0) {skip=0; next}
      if (skip) next
    }
    $0 ~ "PublicKey = "key {
      skip=1
      next
    }
    {print}
  ' "$WG_CONF" > "${WG_CONF}.tmp"

  mv "${WG_CONF}.tmp" "$WG_CONF"
fi

rm -f "$CLIENT_CONF"

systemctl restart wg-quick@wg0

echo "Client $NAME removed"
