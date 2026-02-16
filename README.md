# Shadowsocks VPN Whitelist for OpenWrt

Набор скриптов для управления Shadowsocks VPN на роутерах с OpenWrt.
Трафик к заблокированным/замедленным сайтам идёт через VPN, остальной — напрямую (белый список).

## Возможности

- Белый список доменов — через VPN идут только указанные сайты
- Автообновление списков с GitHub (Re:filter + Zapret)
- Свой список доменов (`my-domains.txt`), который не перезаписывается при обновлении
- Автозапуск VPN при перезагрузке роутера
- Тест скорости и доступности сайтов

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
    ├── domains_all.lst    # [auto] Заблокированные РКН домены (Re:filter)
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

### 1. Настройка роутера

Подключитесь к роутеру по SSH и выполните:
```bash
# Установка пакетов
opkg update
opkg install shadowsocks-libev-ss-local shadowsocks-libev-ss-redir shadowsocks-libev-ss-tunnel

# Создание конфига Shadowsocks (замените данные на свои)
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

### 2. Установка скрипта автозапуска
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
}

stop() {
    killall ss-redir 2>/dev/null
    iptables -t nat -D PREROUTING -p tcp -j SS_REDIR 2>/dev/null
    iptables -t nat -F SS_REDIR 2>/dev/null
    iptables -t nat -X SS_REDIR 2>/dev/null
    ipset flush vpn_list 2>/dev/null
    rm -f /tmp/dnsmasq.d/vpn-whitelist.conf
    /etc/init.d/dnsmasq restart
}
EOF
chmod +x /etc/init.d/shadowsocks
/etc/init.d/shadowsocks enable
```

> **Важно:** замените `YOUR_SERVER_IP` на IP вашего Shadowsocks-сервера в обоих местах (config.json и init.d скрипт).

### 3. Настройка dnsmasq

Убедитесь, что dnsmasq читает конфиги из `/tmp/dnsmasq.d/`. Проверьте:
```bash
grep "conf-dir" /var/etc/dnsmasq.conf* 2>/dev/null
```

Если в выводе `/tmp/dnsmasq.d` — всё ок. Если `/etc/dnsmasq.d` — замените путь в скриптах.

### 4. Использование
```bash
# Скачать списки
vpn-update.bat

# Включить VPN
vpn-start.bat

# Проверить работу
vpn-test.bat

# Выключить VPN
vpn-stop.bat
```

## Добавление своих доменов

Откройте `lists/my-domains.txt` в текстовом редакторе и добавьте домены по одному на строку:
```
x.com
twitter.com
twimg.com
tiktok.com
```

Затем запустите `vpn-start.bat` для применения.

## Как это работает

1. `vpn-update.bat` скачивает актуальные списки доменов с GitHub
2. `vpn-start.bat` загружает списки на роутер, запускает ss-redir и настраивает dnsmasq + ipset + iptables
3. Когда устройство обращается к домену из списка, dnsmasq автоматически добавляет его IP в ipset
4. iptables перенаправляет трафик к IP из ipset через Shadowsocks
5. Остальной трафик идёт напрямую

## Источники списков

- [Re:filter](https://github.com/1andrevich/Re-filter-lists) — актуальный список заблокированных доменов и IP в РФ
- [Zapret](https://github.com/Flowseal/zapret-discord-youtube) — списки замедляемых сервисов (YouTube, Discord, Google)

## Совместимость

Протестировано на:
- GL.iNet Flint 2 (GL-MT6000), OpenWrt 21.02

Должно работать на любом роутере с OpenWrt при наличии необходимых пакетов.

## Благодарности

- [bol-van/zapret](https://github.com/bol-van/zapret) — оригинальный инструмент обхода DPI
- [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube) — списки доменов
- [1andrevich/Re-filter-lists](https://github.com/1andrevich/Re-filter-lists) — списки заблокированных доменов
- [Admonstrator/glinet-remove-chinalock](https://github.com/Admonstrator/glinet-remove-chinalock) — смена региона GL.iNet роутера

## Лицензия

MIT
