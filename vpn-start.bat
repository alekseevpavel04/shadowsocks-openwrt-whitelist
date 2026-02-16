@echo off

echo ========================================
echo   VPN - START
echo ========================================
echo.

set "ROUTER=192.168.8.1"
set "LISTS_DIR=%~dp0lists"

if not exist "%LISTS_DIR%\list-general.txt" (
    echo ERROR: Lists not found. Run vpn-update.bat first.
    pause
    exit /b 1
)

echo [1/2] Uploading lists to router...
scp -O "%LISTS_DIR%\community.lst" "%LISTS_DIR%\list-general.txt" "%LISTS_DIR%\list-google.txt" "%LISTS_DIR%\my-domains.txt" root@%ROUTER%:/etc/shadowsocks-libev/ 2>nul
echo       OK

echo [2/2] Applying VPN config...
ssh root@%ROUTER% "pidof ss-redir >/dev/null 2>&1 || (ss-redir -c /etc/shadowsocks-libev/config.json -b 0.0.0.0 -l 1080 -f /var/run/ss-redir.pid; sleep 1); cat /etc/shadowsocks-libev/community.lst /etc/shadowsocks-libev/list-general.txt /etc/shadowsocks-libev/list-google.txt /etc/shadowsocks-libev/my-domains.txt 2>/dev/null | grep -v '^#' | grep -v '^$' | sort -u | awk '{print \"ipset=/\"$0\"/vpn_list\"}' > /tmp/dnsmasq.d/vpn-whitelist.conf; /etc/init.d/dnsmasq restart >/dev/null 2>&1; ipset create vpn_list hash:ip hashsize 65536 maxelem 131072 -exist; ipset flush vpn_list; iptables -t nat -N SS_REDIR 2>/dev/null; iptables -t nat -F SS_REDIR; iptables -t nat -D PREROUTING -p tcp -j SS_REDIR 2>/dev/null; iptables -t nat -A SS_REDIR -d 158.255.212.150 -j RETURN; iptables -t nat -A SS_REDIR -d 0.0.0.0/8 -j RETURN; iptables -t nat -A SS_REDIR -d 10.0.0.0/8 -j RETURN; iptables -t nat -A SS_REDIR -d 127.0.0.0/8 -j RETURN; iptables -t nat -A SS_REDIR -d 169.254.0.0/16 -j RETURN; iptables -t nat -A SS_REDIR -d 172.16.0.0/12 -j RETURN; iptables -t nat -A SS_REDIR -d 192.168.0.0/16 -j RETURN; iptables -t nat -A SS_REDIR -d 224.0.0.0/4 -j RETURN; iptables -t nat -A SS_REDIR -d 240.0.0.0/4 -j RETURN; iptables -t nat -A SS_REDIR -m set --match-set vpn_list dst -p tcp -j REDIRECT --to-ports 1080; iptables -t nat -A PREROUTING -p tcp -j SS_REDIR; echo 'VPN started.'"

echo.
echo ========================================
echo   VPN is ON
echo ========================================
echo.
pause