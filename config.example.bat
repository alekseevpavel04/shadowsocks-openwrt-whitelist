@echo off
:: VPN config — VLESS+REALITY two-hop chain
:: Copy to config.bat and fill in the values.
:: config.bat is gitignored.
::
:: Topology:
::   router/phone -> RELAY (SPB, Timeweb) -> VPS (Amsterdam, Vultr) -> internet
::   Each hop is an independent VLESS+REALITY handshake with matching SNI->IP.
::
:: Setup order:
::   1. Deploy both servers (Ubuntu 24.04)
::   2. Set VPS_SERVER + RELAY_SERVER below
::   3. Option [A] Setup VPS    -> prints VPS_UUID/VPS_PUBLIC_KEY/VPS_SHORT_ID
::   4. Paste those VPS_* values below
::   5. Option [B] Setup relay  -> prints RELAY_UUID/RELAY_PUBLIC_KEY/RELAY_SHORT_ID
::   6. Paste those RELAY_* values below
::   7. Option [C] Setup router
::   8. Option [1] Start VPN

:: ---- Amsterdam VPS (egress to internet) --------------------
set "VPS_SERVER=YOUR_VPS_IP"
set "VPS_UUID=YOUR_VPS_UUID"
set "VPS_PUBLIC_KEY=YOUR_VPS_PUBLIC_KEY"
set "VPS_SHORT_ID=YOUR_VPS_SHORT_ID"
:: SNI for relay->VPS link. Must resolve to VPS_SERVER. Default via sslip.io
:: (public wildcard DNS, no signup needed, format: <ip>.sslip.io).
:: Override with your own domain if you prefer.
set "VPS_SNI=YOUR_VPS_IP.sslip.io"

:: ---- Russian relay (ingress from router/phone) -------------
set "RELAY_SERVER=YOUR_RELAY_IP"
set "RELAY_UUID=YOUR_RELAY_UUID"
set "RELAY_PUBLIC_KEY=YOUR_RELAY_PUBLIC_KEY"
set "RELAY_SHORT_ID=YOUR_RELAY_SHORT_ID"
:: SNI for client->relay link. Must resolve to RELAY_SERVER.
set "RELAY_SNI=YOUR_RELAY_IP.sslip.io"
