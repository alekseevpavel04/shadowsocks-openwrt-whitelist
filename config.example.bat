@echo off
:: Xray VLESS+REALITY server settings
:: Copy this file to config.bat and fill in your values
:: config.bat is ignored by git — your credentials stay local
::
:: How to get these values:
::   1. Deploy a VPS (Vultr/Hetzner, Ubuntu 24.04)
::   2. Set XRAY_SERVER to the VPS IP
::   3. Run vpn-server-setup.bat — it prints UUID and PUBLIC_KEY

set "XRAY_SERVER=YOUR_VPS_IP"
set "XRAY_UUID=YOUR_UUID"
set "XRAY_PUBLIC_KEY=YOUR_PUBLIC_KEY"
