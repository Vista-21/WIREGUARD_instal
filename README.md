# WireGuard instal (автоматизированный менеджер)

Автоматизированная установка и управление WireGuard на Debian/Ubuntu‑серверах.

## Возможности

- Полностью автоматическая установка WireGuard
- Только IPv4, без IPv6
- MTU = 1280
- PersistentKeepalive = 0
- Автоматическое создание трёх клиентов:
  - `ealme_test`
  - `user_test#1`
  - `user_test#2`
- Удобные команды:
  - `wg-add-client` — добавить клиента
  - `wg-del-client` — удалить клиента
  - `wg-peers` — показать состояние пиров
  - `wg-clean` — полностью удалить WireGuard и все конфиги

## Установка

На чистом сервере Debian/Ubuntu:

```bash
curl -s https://raw.githubusercontent.com/Vista-21/WIREGUARD_instal/main/install-wg.sh | bash
```

После установки:
клиентские конфиги: ~/wg-clients/
серверный конфиг: /etc/wireguard/wg0.conf

После этого у тебя будут доступны команды:
wg-add-client
wg-del-client
wg-peers
wg-clean

Примеры использования:

 - добавить клиента
wg-add-client my_client
 - удалить клиента
wg-del-client my_client
 - показать состояние
wg-peers
 - полностью удалить WireGuard
wg-clean




