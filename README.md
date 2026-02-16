# Shadowsocks VPN Whitelist for OpenWrt

Набор скриптов для управления Shadowsocks VPN на роутерах с OpenWrt.
Трафик к заблокированным/замедленным сайтам идёт через VPN, остальной — напрямую (белый список).

## Возможности

- Белый список доменов — через VPN идут только указанные сайты
- Автообновление списков с GitHub (Re:filter + Zapret)
- Свой список доменов (`my-domains.txt`), который не перезаписывается при обновлении
- Автозапуск VPN при перезагрузке роутера
- Перехват DNS — все устройства в сети используют dnsmasq роутера
- Блокировка UDP к заблокированным сайтам — принудительный переход на TCP через VPN (решает проблему с мобильными приложениями)
- Тест доступности сайтов

## Структура
```
shadowsocks-vpn/
├── vpn-start.bat      # Включить VPN и загрузить списки на роутер
├── vpn-stop.bat       # Выключить VPN
├── vpn-update.bat     # Скачать свежие списки с GitHub
├── vpn-test.bat       # Тест доступности сайтов
├── .gitignore
├── README.md
└── lists/
    ├── community.lst      # [auto] Популярные заблокированные сервисы (Re:filter)
    ├── list-general.txt   # [auto] Замедляемые домены (Zapret)
    ├── list-google.txt    # [auto] Google/YouTube домены (Zapret)
    └── my-domains.txt     # Ваши домены (редактируется вручную)
```

## Требования

- Роутер с OpenWrt (протестировано на GL.iNet Flint 2 / GL-MT6000)
- Установленные пакеты: `shadowsocks-libev-ss-redir`, `dnsmasq-full`, `ipset`
- Настроенный конфиг Shadowsocks на роутере (`/etc/shadowsocks-libev/config.json`)
- Windows 10/11 с встроенным SSH-клиентом

## Первоначальная настройка

### 1. Установка пакетов на роутере
```bash
opkg update
opkg install shadowsocks-libev-ss-local shadowsocks-libev-ss-redir shadowsocks-libev-ss-tunnel
```

### 2. Создание конфига Shadowsocks
```bash
cat > /etc/shadowsocks-libev/config.json << 'EOF'
{
    "server": "YOUR_SERVER_IP",
    "server_port": 443,
    "password": "YOUR_PASSWORD",
    "method": "chacha20-ietf-poly1305",
    "local_address": "0.0.0.0",
    "local_port": 1080,
    "timeout": 300
}
EOF
```

### 3. Установка скрипта автозапуска

Замените `YOUR_SERVER_IP` на IP вашего Shadowsocks-сервера.
```bash
cat > /etc/init.d/shadowsocks << 'EOF'
#!/bin/sh /etc/rc.common
START=99

start() {
    ss-redir -c /etc/shadowsocks-libev/config.json -b 0.0.0.0 -l 1080 -f /var/run/ss-redir.pid
    sleep 2
    ipset create vpn_list hash:ip hashsize 65536 maxelem 131072 -exist
    ipset flush vpn_list
    cat /etc/shadowsocks-libev/community.lst /etc/shadowsocks-libev/list-general.txt /etc/shadowsocks-libev/list-google.txt /etc/shadowsocks-libev/my-domains.txt 2>/dev/null | grep -v '^#' | grep -v '^$' | sort -u | awk '{print "ipset=/"$0"/vpn_list"}' > /tmp/dnsmasq.d/vpn-whitelist.conf
    /etc/init.d/dnsmasq restart
    iptables -t nat -N SS_REDIR 2>/dev/null
    iptables -t nat -F SS_REDIR
    iptables -t nat -D PREROUTING -p tcp -j SS_REDIR 2>/dev/null
    iptables -t nat -A SS_REDIR -d YOUR_SERVER_IP -j RETURN
    iptables -t nat -A SS_REDIR -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A SS_REDIR -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A SS_REDIR -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A SS_REDIR -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A SS_REDIR -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A SS_REDIR -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A SS_REDIR -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A SS_REDIR -d 240.0.0.0/4 -j RETURN
    iptables -t nat -A SS_REDIR -m set --match-set vpn_list dst -p tcp -j REDIRECT --to-ports 1080
    iptables -t nat -A PREROUTING -p tcp -j SS_REDIR
    iptables -t nat -A PREROUTING -p udp --dport 53 ! -d 192.168.8.1 -j DNAT --to-destination 192.168.8.1:53
    iptables -t nat -A PREROUTING -p tcp --dport 53 ! -d 192.168.8.1 -j DNAT --to-destination 192.168.8.1:53
    iptables -I FORWARD -p udp -m set --match-set vpn_list dst -j DROP
}

stop() {
    killall ss-redir 2>/dev/null
    iptables -t nat -D PREROUTING -p tcp -j SS_REDIR 2>/dev/null
    iptables -t nat -F SS_REDIR 2>/dev/null
    iptables -t nat -X SS_REDIR 2>/dev/null
    iptables -t nat -D PREROUTING -p udp --dport 53 ! -d 192.168.8.1 -j DNAT --to-destination 192.168.8.1:53 2>/dev/null
    iptables -t nat -D PREROUTING -p tcp --dport 53 ! -d 192.168.8.1 -j DNAT --to-destination 192.168.8.1:53 2>/dev/null
    iptables -D FORWARD -p udp -m set --match-set vpn_list dst -j DROP 2>/dev/null
    ipset flush vpn_list 2>/dev/null
    rm -f /tmp/dnsmasq.d/vpn-whitelist.conf
    /etc/init.d/dnsmasq restart
}
EOF
chmod +x /etc/init.d/shadowsocks
/etc/init.d/shadowsocks enable
```

### 4. Важно: путь dnsmasq

Убедитесь, что dnsmasq читает конфиги из `/tmp/dnsmasq.d/`:
```bash
grep "conf-dir" /var/etc/dnsmasq.conf* 2>/dev/null
```

Если в выводе другой путь — замените `/tmp/dnsmasq.d/` в скриптах на ваш.

## Использование
```
vpn-update.bat     # Скачать свежие списки (раз в неделю)
vpn-start.bat      # Включить VPN
vpn-test.bat       # Проверить доступность сайтов
vpn-stop.bat       # Выключить VPN
```

При перезагрузке роутера VPN запускается автоматически.

## Добавление своих доменов

Откройте `lists/my-domains.txt` и добавьте домены по одному на строку:
```
x.com
twitter.com
twimg.com
tiktok.com
spotify.com
```

Затем запустите `vpn-start.bat` для применения.

## Как это работает

1. `vpn-update.bat` скачивает актуальные списки доменов с GitHub
2. `vpn-start.bat` загружает списки на роутер и настраивает dnsmasq + ipset + iptables
3. DNS-запросы всех устройств перехватываются и направляются на dnsmasq роутера
4. Когда устройство обращается к домену из списка, dnsmasq добавляет его IP в ipset
5. iptables перенаправляет TCP-трафик к IP из ipset через Shadowsocks
6. UDP-трафик к заблокированным IP блокируется, вынуждая приложения использовать TCP через VPN
7. Остальной трафик идёт напрямую

## Рекомендации

- **Отключите QUIC в Chrome**: `chrome://flags/#enable-quic` → Disabled. YouTube и Google используют QUIC (UDP), который не проходит через VPN.
- **Отключите IPv6** на роутере — наш VPN работает только через IPv4, IPv6-трафик обойдёт VPN.
- Обновляйте списки раз в неделю через `vpn-update.bat`

## Известные ограничения

- Только TCP-трафик идёт через VPN. UDP блокируется для заблокированных сайтов, вынуждая приложения переключаться на TCP.
- Голосовые звонки Discord (UDP) могут не работать через роутерный VPN. Для звонков используйте VPN-приложение на устройстве.
- Первое обращение к новому домену может быть медленным — ipset наполняется при DNS-запросе.
- При обновлении прошивки роутера все настройки слетят — потребуется повторная установка.

## Источники списков

- [Re:filter](https://github.com/1andrevich/Re-filter-lists) — актуальный список заблокированных доменов и IP в РФ
- [Zapret](https://github.com/Flowseal/zapret-discord-youtube) — списки замедляемых сервисов (YouTube, Discord, Google)

## Совместимость

Протестировано на:
- GL.iNet Flint 2 (GL-MT6000), OpenWrt 21.02

Должно работать на любом роутере с OpenWrt при наличии необходимых пакетов (`shadowsocks-libev-ss-redir`, `dnsmasq-full`, `ipset`).

## Благодарности

- [bol-van/zapret](https://github.com/bol-van/zapret) — оригинальный инструмент обхода DPI
- [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube) — списки доменов
- [1andrevich/Re-filter-lists](https://github.com/1andrevich/Re-filter-lists) — списки заблокированных доменов
- [Admonstrator/glinet-remove-chinalock](https://github.com/Admonstrator/glinet-remove-chinalock) — смена региона GL.iNet роутера

## Лицензия

MIT
