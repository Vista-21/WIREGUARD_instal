#!/bin/bash

set -e

echo "Checking OS version..."
OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
OS_VER=$(grep -oP '(?<=VERSION_ID=").+(?=")' /etc/os-release)

echo "Detected: $OS_ID $OS_VER"

# --- Проверка, установлен ли WireGuard ---
if command -v wg >/dev/null 2>&1; then
    echo "WireGuard is already installed. Skipping installation to avoid conflicts."
    echo "If you want to reinstall, run: wg-clean"
    exit 0
fi

# --- Автоматическая фиксация репозиториев для Debian 11/12 ---
if [[ "$OS_ID" == "debian" && ( "$OS_VER" == "11" || "$OS_VER" == "12" ) ]]; then
    echo "Debian $OS_VER detected — fixing repositories..."

    echo "Removing broken backports entries..."
    sed -i '/backports/d' /etc/apt/sources.list 2>/dev/null || true
    sed -i '/backports/d' /etc/apt/sources.list.d/*.list 2>/dev/null || true
    sed -i '/backports/d' /etc/apt/sources.list.d/*.sources 2>/dev/null || true

    echo "Rebuilding /etc/apt/sources.list..."
    cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian bullseye main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb http://security.debian.org/debian-security bullseye-security main contrib non-free
EOF

    echo "Updating APT..."
    apt update
else
    echo "Non-Debian or unsupported Debian version detected — skipping repo fix."
fi

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
