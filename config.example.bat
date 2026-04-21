@echo off
:: Xray VLESS+REALITY server settings
:: Copy this file to config.bat and fill in your values
:: config.bat is ignored by git — your credentials stay local
::
:: Setup order:
::   1. Deploy Amsterdam VPS (Vultr/Hetzner, Ubuntu 24.04)
::   2. Set XRAY_SERVER, run vpn-addkey-vps.bat + vpn-setup-vps.bat
::   3. Deploy Russian relay VPS (Timeweb, Ubuntu 22.04/24.04)
::   4. Set RELAY_SERVER, run vpn-addkey-relay.bat + vpn-setup-relay.bat
::   5. Run vpn-setup.bat (router), then vpn-start.bat

:: Amsterdam VPS (Vultr) — Xray VLESS+REALITY server
set "XRAY_SERVER=YOUR_VPS_IP"
set "XRAY_UUID=YOUR_UUID"
set "XRAY_PUBLIC_KEY=YOUR_PUBLIC_KEY"
set "XRAY_SHORT_ID=YOUR_SHORT_ID"

:: SNI domain for REALITY — must be a domain whose A record points to XRAY_SERVER.
:: Get a free subdomain at duckdns.org, set A record = XRAY_SERVER, paste domain here.
:: Example: myvpn1345.duckdns.org  (do NOT use www.microsoft.com — TSPU blocks SNI↔IP mismatches)
set "XRAY_SNI=YOUR_DOMAIN.duckdns.org"

:: Russian relay (Timeweb) — socat TCP relay to XRAY_SERVER
:: Leave as YOUR_RELAY_IP (or empty) to connect directly to Amsterdam
set "RELAY_SERVER=YOUR_RELAY_IP"
