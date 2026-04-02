#!/bin/bash

set -e

# --- ASCII Banner ---
clear
cat << "EOF"
 __        ___           ____                          _ 
 \ \      / (_)_ __     / ___|___  _ ____   _____ _ __| |
  \ \ /\ / /| | '_ \   | |   / _ \| '_ \ \ / / _ \ '__| |
   \ V  V / | | | | |  | |__| (_) | | | \ V /  __/ |  | |
    \_/\_/  |_|_| |_|   \____\___/|_| |_|\_/ \___|_|  |_|

        W I R E G U A R D   I N S T A L L E R
        --------------------------------------
              Automated setup & management
EOF
echo
sleep 1

echo "Checking OS version..."
OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
OS_VER=$(grep -oP '(?<=VERSION_ID=").+(?=")' /etc/os-release)

echo "Detected: $OS_ID $OS_VER"

###############################################
# ЗАПРОС ПОРТА WIREGUARD (с проверкой stdin)
###############################################
DEFAULT_PORT=37821

if [ -t 0 ]; then
    echo
    read -p "Введите порт для WireGuard (по умолчанию $DEFAULT_PORT): " SERVER_PORT
    SERVER_PORT=${SERVER_PORT:-$DEFAULT_PORT}

    if ! [[ "$SERVER_PORT" =~ ^[0-9]+$ ]] || [ "$SERVER_PORT" -lt 1 ] || [ "$SERVER_PORT" -gt 65535 ]; then
        echo "Некорректный порт. Использую $DEFAULT_PORT."
        SERVER_PORT=$DEFAULT_PORT
    fi
else
    echo
    echo "stdin недоступен — использую порт по умолчанию $DEFAULT_PORT"
    SERVER_PORT=$DEFAULT_PORT
fi

echo "WireGuard port set to: $SERVER_PORT"
echo

###############################################
# ПРОВЕРКА, УСТАНОВЛЕН ЛИ WIREGUARD
###############################################
if command -v wg >/dev/null 2>&1; then
    echo "WireGuard is already installed. Skipping installation to avoid conflicts."
    echo "If you want to reinstall, run: wg-clean"
    exit 0
fi

###############################################
# ИСПРАВЛЕНИЕ РЕПОЗИТОРИЕВ DEBIAN 11/12
###############################################
if [[ "$OS_ID" == "debian" && ( "$OS_VER" == "11" || "$OS_VER" == "12" ) ]]; then
    echo "Debian $OS_VER detected — fixing repositories..."

    sed -i '/backports/d' /etc/apt/sources.list 2>/dev/null || true
    sed -i '/backports/d' /etc/apt/sources.list.d/*.list 2>/dev/null || true
    sed -i '/backports/d' /etc/apt/sources.list.d/*.sources 2>/dev/null || true

    rm -f /etc/apt/sources.list.d/default.list 2>/dev/null || true
    rm -f /etc/apt/sources.list.d/updates.list 2>/dev/null || true

    cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian bullseye main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb http://security.debian.org/debian-security bullseye-security main contrib non-free
EOF

    apt update
else
    echo "Non-Debian or unsupported Debian version detected — skipping repo fix."
fi

REPO="https://raw.githubusercontent.com/Vista-21/WIREGUARD_instal/main"

###############################################
# УСТАНОВКА WIREGUARD
###############################################
echo "Updating system..."
apt update

echo "Checking nano..."
if ! command -v nano >/dev/null 2>&1; then
    apt install -y nano
fi

echo "Installing WireGuard..."
apt install -y wireguard iptables curl wget

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

###############################################
# УСТАНОВКА VK TURN PROXY
###############################################
echo "Installing VK TURN Proxy..."

WG_PORT=$(grep -oP '(?<=ListenPort = )\d+' /etc/wireguard/wg0.conf)
echo "Detected WireGuard port: $WG_PORT"

mkdir -p /opt/vk-turn-proxy
cd /opt/vk-turn-proxy

wget -q https://github.com/kiper292/vk-turn-proxy/releases/download/v2.0.2/server-linux-amd64 -O server
chmod +x server

cat > /etc/systemd/system/vk-turn-proxy.service <<EOF
[Unit]
Description=VK TURN Proxy
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/vk-turn-proxy
ExecStart=/opt/vk-turn-proxy/server -listen 0.0.0.0:56000 -connect 127.0.0.1:$WG_PORT
Restart=always
RestartSec=3
User=root
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vk-turn-proxy
systemctl start vk-turn-proxy

echo "VK TURN Proxy installed and running."

###############################################
# СОЗДАЁМ vk-turn-clean
###############################################
cat > /usr/local/bin/vk-turn-clean <<EOF
#!/bin/bash
systemctl stop vk-turn-proxy 2>/dev/null
systemctl disable vk-turn-proxy 2>/dev/null
rm -f /etc/systemd/system/vk-turn-proxy.service
rm -rf /opt/vk-turn-proxy
systemctl daemon-reload
echo "VK TURN Proxy fully removed."
EOF

chmod +x /usr/local/bin/vk-turn-clean

echo
echo "WireGuard installation complete."
echo "Clients are in: ~/wg-clients/"
echo "Commands: wg-add-client, wg-del-client, wg-peers, wg-clean, vk-turn-clean"
