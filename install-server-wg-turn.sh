#!/bin/bash

set -e

###############################################
# ЦВЕТА И ФУНКЦИИ ВЫВОДА
###############################################
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
NC="\e[0m"

ok()    { echo -e "${GREEN}[ OK ]${NC} $1"; }
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERR ]${NC} $1"; }

###############################################
# ASCII БАННЕР
###############################################
clear
cat << "EOF"
 __        ___           ____                          _
 \ \      / (_)_ __     / ___|___  _ ____   _____ _ __| |
  \ \ /\ / /| | '_ \   | |   / _ \| '_ \ \ / / _ \ '__| |
   \ V  V / | | | | |  | |__| (_) | | | \ V /  __/ |  | |
    \_/\_/  |_|_| |_|   \____\___/|_| |_|\_/ \___|_|  |_|

     W I R E G U A R D  +  V K   T U R N   S E R V E R
     --------------------------------------------------
              Automated setup & management
EOF
echo
sleep 1

###############################################
# ОПРЕДЕЛЕНИЕ ОС
###############################################
info "Checking OS version..."
OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
OS_CODENAME=$(grep -oP '(?<=VERSION_CODENAME=).+' /etc/os-release)
info "Detected: $OS_ID ($OS_CODENAME)"

###############################################
# ЗАПРОС ПОРТА С ПРОВЕРКОЙ ЗАНЯТОСТИ
###############################################
DEFAULT_PORT=37821

get_free_port() {
    local PORT
    while true; do
        if [ -t 0 ]; then
            read -p "Введите порт для WireGuard (по умолчанию $DEFAULT_PORT): " PORT
            PORT=${PORT:-$DEFAULT_PORT}
        else
            warn "stdin недоступен — порт выбран автоматически"
            PORT=$DEFAULT_PORT
        fi

        if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
            error "Порт должен быть числом"
            continue
        fi

        if ss -tuln | grep -q ":$PORT "; then
            PROC=$(ss -tulnp | grep ":$PORT " | awk -F '"' '{print $2}')
            error "Порт $PORT уже используется процессом: $PROC"
            continue
        fi

        echo "$PORT"
        return
    done
}

SERVER_PORT=$(get_free_port)
ok "WireGuard port set to: $SERVER_PORT"
echo

###############################################
# ПРОВЕРКА, УСТАНОВЛЕН ЛИ WIREGUARD
###############################################
if command -v wg >/dev/null 2>&1; then
    warn "WireGuard уже установлен. Используйте wg-clean для удаления."
    exit 0
fi

###############################################
# ИСПРАВЛЕНИЕ РЕПОЗИТОРИЕВ DEBIAN (БЕЗ BACKPORTS)
###############################################
if [[ "$OS_ID" == "debian" ]]; then
    info "Fixing Debian repositories..."

    rm -f /etc/apt/sources.list.d/*.list

    cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian $OS_CODENAME main contrib non-free
deb http://deb.debian.org/debian $OS_CODENAME-updates main contrib non-free
deb http://security.debian.org/debian-security $OS_CODENAME-security main contrib non-free
EOF

    apt update
    ok "Debian repositories fixed"
fi

###############################################
# URL РЕПОЗИТОРИЯ
###############################################
REPO="https://raw.githubusercontent.com/Vista-21/WG-TURN-server-installer/main"

###############################################
# УСТАНОВКА WIREGUARD
###############################################
info "Installing WireGuard..."
apt install -y wireguard iptables curl wget qrencode whiptail
ok "WireGuard installed"

###############################################
# УСТАНОВКА NANO
###############################################
if ! command -v nano >/dev/null 2>&1; then
    info "Installing nano..."
    apt install -y nano
    ok "nano installed"
else
    ok "nano already installed"
fi

mkdir -p /etc/wireguard
mkdir -p ~/wg-clients

###############################################
# СКАЧИВАНИЕ СКРИПТОВ
###############################################
info "Downloading management scripts..."
curl -s -o /usr/local/bin/wg-add-client $REPO/wg-add-client.sh
curl -s -o /usr/local/bin/wg-del-client $REPO/wg-del-client.sh
curl -s -o /usr/local/bin/wg-peers      $REPO/wg-peers.sh
curl -s -o /usr/local/bin/wg-clean      $REPO/wg-clean.sh
curl -s -o /usr/local/bin/wg-menu       $REPO/wg-menu
chmod +x /usr/local/bin/wg-*
ok "Management scripts installed"

###############################################
# ГЕНЕРАЦИЯ КЛЮЧЕЙ
###############################################
info "Generating server keys..."
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
SERVER_PRIV=$(cat /etc/wireguard/server_private.key)
SERVER_PUB=$(cat /etc/wireguard/server_public.key)
ok "Keys generated"

###############################################
# ВНЕШНИЙ IP
###############################################
SERVER_IP=$(curl -4 -s ifconfig.me)
export SERVER_IP

###############################################
# СОЗДАНИЕ wg0.conf
###############################################
WG_ADDR="10.8.0.1/24"
MTU=1280
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')

info "Creating wg0.conf..."
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = $WG_ADDR
ListenPort = $SERVER_PORT
PrivateKey = $SERVER_PRIV
MTU = $MTU
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $IFACE -j MASQUERADE
EOF
ok "wg0.conf created"

###############################################
# СОЗДАНИЕ КЛИЕНТОВ
###############################################
info "Creating default clients..."
wg-add-client main_test
wg-add-client user_test-1
wg-add-client user_test-2
ok "Clients created"

systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0
ok "WireGuard started"

###############################################
# АРХИТЕКТУРА
###############################################
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  VK_BIN="server-linux-amd64" ;;
    aarch64) VK_BIN="server-linux-arm64" ;;
    *)
        error "Неподдерживаемая архитектура: $ARCH"
        exit 1
        ;;
esac
ok "Detected architecture: $ARCH"

###############################################
# УСТАНОВКА VK TURN PROXY
###############################################
info "Installing VK TURN Proxy..."

WG_PORT=$(grep -oP '(?<=ListenPort = )\d+' /etc/wireguard/wg0.conf)

mkdir -p /opt/vk-turn-proxy
cd /opt/vk-turn-proxy

wget -q "https://github.com/kiper292/vk-turn-proxy/releases/download/v2.0.2/$VK_BIN" -O server
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
ok "VK TURN Proxy installed and running"

###############################################
# ФИНАЛ
###############################################
echo
ok "WireGuard + VK TURN installation complete"
info "Clients stored in: ~/wg-clients/"
info "Commands: wg-add-client, wg-del-client, wg-peers, wg-clean, vk-turn-clean, wg-menu"
echo
