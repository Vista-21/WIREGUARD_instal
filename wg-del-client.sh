#!/bin/bash

NAME="$1"

if [ -z "$NAME" ]; then
    echo "Usage: wg-del-client <client_name>"
    exit 1
fi

PUB=$(cat /etc/wireguard/${NAME}_public.key 2>/dev/null)

if [ -z "$PUB" ]; then
    echo "Client not found"
    exit 1
fi

sed -i "/$PUB/,+2d" /etc/wireguard/wg0.conf

rm -f /etc/wireguard/${NAME}_private.key
rm -f /etc/wireguard/${NAME}_public.key
rm -f ~/wg-clients/${NAME}.conf

systemctl restart wg-quick@wg0
echo "Client $NAME removed"
