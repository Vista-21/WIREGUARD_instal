#!/bin/bash

set -e

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
NC="\e[0m"

ok()    { echo -e "${GREEN}[ OK ]${NC} $1"; }
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERR ]${NC} $1"; }

echo
echo "WireGuard + VK TURN full cleanup started..."
echo

###############################################
# ОСТАНОВКА И УДАЛЕНИЕ VK TURN PROXY
###############################################
if command -v vk-turn-clean >/dev/null 2>&1; then
    info "Using vk-turn-clean to remove VK TURN Proxy..."
    vk-turn-clean || warn "vk-turn-clean finished with warnings"
    ok "VK TURN Proxy removed via vk-turn-clean"
else
    info "vk-turn-clean not found, removing VK TURN Proxy manually..."

    systemctl stop vk-turn-proxy 2>/dev/null || true
    systemctl disable vk-turn-proxy 2>/dev/null || true
    rm -f /etc/systemd/system/vk-turn-proxy.service
    rm -rf /opt/vk-turn-proxy

    systemctl daemon-reload
    ok "VK TURN Proxy removed manually"
fi

###############################################
# ОСТАНОВКА И УДАЛЕНИЕ WIREGUARD
###############################################
info "Stopping WireGuard..."
systemctl stop wg-quick@wg0 2>/dev/null || true
systemctl disable wg-quick@wg0 2>/dev/null || true
rm -f /etc/systemd/system/multi-user.target.wants/wg-quick@wg0.service 2>/dev/null || true
systemctl daemon-reload
ok "WireGuard service disabled"

###############################################
# УДАЛЕНИЕ КОНФИГОВ И КЛЮЧЕЙ
###############################################
info "Removing WireGuard configs and keys..."
rm -rf /etc/wireguard
rm -rf ~/wg-clients
ok "Configs and clients removed"

###############################################
# УДАЛЕНИЕ СКРИПТОВ УПРАВЛЕНИЯ
###############################################
info "Removing management scripts..."
rm -f /usr/local/bin/wg-add-client
rm -f /usr/local/bin/wg-del-client
rm -f /usr/local/bin/wg-peers
rm -f /usr/local/bin/vk-turn-clean
ok "Management scripts removed"

###############################################
# УДАЛЕНИЕ TUI МЕНЮ
###############################################
info "Removing TUI menu (wg-menu)..."
rm -f /usr/local/bin/wg-menu
ok "wg-menu removed"

###############################################
# ОПЦИОНАЛЬНО: УДАЛЕНИЕ wireguard ПАКЕТОВ
###############################################
if dpkg -l | grep -q wireguard; then
    info "Removing WireGuard packages..."
    apt remove -y wireguard wireguard-tools 2>/dev/null || true
    ok "WireGuard packages removed"
else
    warn "WireGuard packages not found in dpkg, skipping"
fi

###############################################
# УДАЛЕНИЕ САМОГО wg-clean
###############################################
info "Removing wg-clean itself..."
SELF_PATH=$(command -v wg-clean || echo "/usr/local/bin/wg-clean")
rm -f "$SELF_PATH"
ok "wg-clean removed"

echo
ok "Full cleanup complete"
echo
