@echo off
setlocal DisableDelayedExpansion
echo ========================================
echo   VPN - START
echo ========================================
echo.

:: Load config
if not exist "%~dp0..\config.bat" (
    echo ERROR: config.bat not found.
    echo Copy config.example.bat to config.bat and fill in your server details.
    echo.
    pause
    exit /b 1
)
call "%~dp0..\config.bat"

set "ROUTER=192.168.8.1"
set "LISTS_DIR=%~dp0..\lists"
set "TEMPLATES_DIR=%~dp0..\templates"

:: Use relay if configured, otherwise connect directly to Amsterdam VPS
set "CONNECT_SERVER=%XRAY_SERVER%"
if not "%RELAY_SERVER%"=="" if not "%RELAY_SERVER%"=="YOUR_RELAY_IP" set "CONNECT_SERVER=%RELAY_SERVER%"

if not exist "%LISTS_DIR%\list-general.txt" (
    echo ERROR: Lists not found. Run option [3] Update lists first.
    pause
    exit /b 1
)

echo [1/3] Uploading xray config to router...
set "TMPCONFIG=%TEMP%\xray-router.json"
powershell -Command "$c=(Get-Content '%TEMPLATES_DIR%\xray-router.json') -replace '__SERVER_IP__','%CONNECT_SERVER%' -replace '__UUID__','%XRAY_UUID%' -replace '__PUBLIC_KEY__','%XRAY_PUBLIC_KEY%'; [System.IO.File]::WriteAllLines('%TMPCONFIG%',$c)"
ssh root@%ROUTER% "mkdir -p /etc/xray"
scp -O "%TMPCONFIG%" root@%ROUTER%:/etc/xray/config.json
if %errorlevel% neq 0 (
    echo       FAILED
    pause
    exit /b 1
)
echo       OK

echo [2/3] Uploading lists to router...
ssh root@%ROUTER% "mkdir -p /etc/shadowsocks-libev"
scp -O "%LISTS_DIR%\community.lst" "%LISTS_DIR%\list-general.txt" "%LISTS_DIR%\list-google.txt" "%LISTS_DIR%\my-domains.txt" root@%ROUTER%:/etc/shadowsocks-libev/ 2>nul
echo       OK

echo [3/3] Applying VPN config...
ssh root@%ROUTER% "killall -9 xray ss-local sslocal ss-redir 2>/dev/null; sleep 1; /usr/local/bin/xray run -c /etc/xray/config.json > /tmp/xray.log 2>&1 & sleep 2; if pidof xray >/dev/null 2>&1; then echo 'xray: running (VLESS+REALITY)'; cat /etc/shadowsocks-libev/community.lst /etc/shadowsocks-libev/list-general.txt /etc/shadowsocks-libev/list-google.txt /etc/shadowsocks-libev/my-domains.txt 2>/dev/null | grep -v '^#' | grep -v '^$' | sort -u > /tmp/vpn-domains.txt; awk '{print \"ipset=/\"$0\"/vpn_list\"}' /tmp/vpn-domains.txt > /tmp/dnsmasq.d/vpn-whitelist.conf; /etc/init.d/dnsmasq restart >/dev/null 2>&1; iptables -t nat -F SS_REDIR 2>/dev/null; iptables -D FORWARD -p udp -m set --match-set vpn_list dst -j DROP 2>/dev/null; ipset destroy vpn_list 2>/dev/null; ipset create vpn_list hash:net hashsize 65536 maxelem 131072; ipset flush vpn_list; ipset add vpn_list 91.108.4.0/22 -exist; ipset add vpn_list 91.108.8.0/22 -exist; ipset add vpn_list 91.108.12.0/22 -exist; ipset add vpn_list 91.108.16.0/22 -exist; ipset add vpn_list 91.108.56.0/22 -exist; ipset add vpn_list 149.154.160.0/20 -exist; ipset add vpn_list 91.105.192.0/23 -exist; ipset add vpn_list 185.76.151.0/24 -exist; iptables -t nat -N SS_REDIR 2>/dev/null; iptables -t nat -F SS_REDIR; iptables -t nat -D PREROUTING -p tcp -j SS_REDIR 2>/dev/null; iptables -t nat -A SS_REDIR -d %CONNECT_SERVER% -j RETURN; iptables -t nat -A SS_REDIR -d 0.0.0.0/8 -j RETURN; iptables -t nat -A SS_REDIR -d 10.0.0.0/8 -j RETURN; iptables -t nat -A SS_REDIR -d 127.0.0.0/8 -j RETURN; iptables -t nat -A SS_REDIR -d 169.254.0.0/16 -j RETURN; iptables -t nat -A SS_REDIR -d 172.16.0.0/12 -j RETURN; iptables -t nat -A SS_REDIR -d 192.168.0.0/16 -j RETURN; iptables -t nat -A SS_REDIR -d 224.0.0.0/4 -j RETURN; iptables -t nat -A SS_REDIR -d 240.0.0.0/4 -j RETURN; iptables -t nat -A SS_REDIR -m set --match-set vpn_list dst -p tcp -j REDIRECT --to-ports 1080; iptables -t nat -A PREROUTING -p tcp -j SS_REDIR; iptables -D INPUT -p tcp --dport 1080 -m conntrack --ctstate DNAT -j ACCEPT 2>/dev/null; iptables -D INPUT -p tcp --dport 1080 -j DROP 2>/dev/null; iptables -I INPUT 1 -p tcp --dport 1080 -m conntrack --ctstate DNAT -j ACCEPT; iptables -I INPUT 2 -p tcp --dport 1080 -j DROP; iptables -t nat -D PREROUTING -p udp --dport 53 ! -d 192.168.8.1 -j DNAT --to-destination 192.168.8.1:53 2>/dev/null; iptables -t nat -A PREROUTING -p udp --dport 53 ! -d 192.168.8.1 -j DNAT --to-destination 192.168.8.1:53; iptables -t nat -D PREROUTING -p tcp --dport 53 ! -d 192.168.8.1 -j DNAT --to-destination 192.168.8.1:53 2>/dev/null; iptables -t nat -A PREROUTING -p tcp --dport 53 ! -d 192.168.8.1 -j DNAT --to-destination 192.168.8.1:53; iptables -D FORWARD -p udp -m set --match-set vpn_list dst -j DROP 2>/dev/null; iptables -I FORWARD -p udp -m set --match-set vpn_list dst -j DROP; for d in youtube.com googlevideo.com youtu.be discord.com instagram.com x.com tiktok.com facebook.com; do nslookup $d 127.0.0.1 >/dev/null 2>&1; done; echo 'VPN started.'; else echo 'ERROR: xray failed to start:'; cat /tmp/xray.log; exit 1; fi"
if %errorlevel% neq 0 (
    echo.
    echo ERROR: VPN start failed. See output above.
    pause
    exit /b 1
)
echo.
echo ========================================
echo   VPN is ON
echo ========================================
echo.
pause