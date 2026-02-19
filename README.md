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
├── vpn-setup.bat          # Первоначальная настройка роутера с нуля
├── vpn-start.bat          # Включить VPN и загрузить списки на роутер
├── vpn-stop.bat           # Выключить VPN
├── vpn-update.bat         # Скачать свежие списки с GitHub
├── vpn-test.bat           # Тест доступности сайтов
├── config.example.bat     # Шаблон конфига (скопировать в config.bat)
├── config.bat             # Ваши данные сервера (не в git)
├── .gitignore
├── README.md
├── templates/
│   └── shadowsocks-init.sh    # Скрипт автозапуска для роутера
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

### 1. Заполнить конфиг с данными сервера

Скопируйте `config.example.bat` в `config.bat` и укажите свои данные:
```
SS_SERVER   — IP вашего Shadowsocks-сервера
SS_PORT     — порт (обычно 443)
SS_PASSWORD — пароль
SS_METHOD   — метод шифрования (например chacha20-ietf-poly1305)
```

### 2. Скачать списки доменов
```
vpn-update.bat
```

### 3. Настроить роутер одной командой
```
vpn-setup.bat
```

Скрипт автоматически:
- Установит нужные пакеты на роутере (`opkg install`)
- Запишет `config.json` на роутер
- Установит и включит скрипт автозапуска
- Загрузит списки доменов

### Важно: путь dnsmasq

Убедитесь, что dnsmasq читает конфиги из `/tmp/dnsmasq.d/`:
```bash
grep "conf-dir" /var/etc/dnsmasq.conf* 2>/dev/null
```

Если в выводе другой путь — замените `/tmp/dnsmasq.d/` в `templates/shadowsocks-init.sh` на ваш, затем снова запустите `vpn-setup.bat`.

## Использование
```
vpn-setup.bat      # Первоначальная настройка роутера с нуля
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
