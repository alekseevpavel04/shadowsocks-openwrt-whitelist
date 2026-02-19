@echo off
:: Shadowsocks server settings
:: Copy this file to config.bat and fill in your values
:: config.bat is ignored by git — your credentials stay local

set "SS_SERVER=YOUR_SERVER_IP"
set "SS_PORT=443"
set "SS_PASSWORD=YOUR_PASSWORD"
set "SS_METHOD=chacha20-ietf-poly1305"
