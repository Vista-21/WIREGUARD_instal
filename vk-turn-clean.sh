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

info "Stopping VK TURN Proxy..."

if systemctl is-active --quiet vk-turn-proxy; then
    systemctl stop vk-turn-proxy
    ok "VK TURN Proxy stopped"
else
    warn "VK TURN Proxy was not running"
fi

info "Disabling VK TURN Proxy..."
if systemctl is-enabled --quiet vk-turn-proxy; then
    systemctl disable vk-turn-proxy
    ok "VK TURN Proxy disabled"
else
    warn "VK TURN Proxy was not enabled"
fi

info "Removing systemd unit..."
if [ -f /etc/systemd/system/vk-turn-proxy.service ]; then
    rm -f /etc/systemd/system/vk-turn-proxy.service
    systemctl daemon-reload
    ok "Systemd unit removed"
else
    warn "Systemd unit not found"
fi

info "Removing VK TURN binary and directory..."
if [ -d /opt/vk-turn-proxy ]; then
    rm -rf /opt/vk-turn-proxy
    ok "VK TURN directory removed"
else
    warn "/opt/vk-turn-proxy not found"
fi

ok "VK TURN Proxy cleanup complete"
