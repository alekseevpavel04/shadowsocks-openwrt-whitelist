@echo off
echo ========================================
echo   VPN - START
echo ========================================
echo.

:: Load config
if not exist "%~dp0config.bat" (
    echo ERROR: config.bat not found.
    echo Copy config.example.bat to config.bat and fill in your server details.
    echo.
    pause
    exit /b 1
)
call "%~dp0config.bat"

set "ROUTER=192.168.8.1"
set "LISTS_DIR=%~dp0lists"
if not exist "%LISTS_DIR%\list-general.txt" (
    echo ERROR: Lists not found. Run vpn-update.bat first.
    pause
    exit /b 1
)

echo [1/3] Pushing Shadowsocks config to router...
echo {"server":"%SS_SERVER%","server_port":%SS_PORT%,"password":"%SS_PASSWORD%","method":"%SS_METHOD%","local_address":"0.0.0.0","local_port":1080,"timeout":300}| ssh root@%ROUTER% "cat > /etc/shadowsocks-libev/config.json"
echo       OK

echo [2/3] Uploading lists to router...
scp -O "%LISTS_DIR%\community.lst" "%LISTS_DIR%\list-general.txt" "%LISTS_DIR%\list-google.txt" "%LISTS_DIR%\my-domains.txt" root@%ROUTER%:/etc/shadowsocks-libev/ 2>nul
echo       OK

echo [3/3] Applying VPN config...
ssh root@%ROUTER% "pidof ss-redir >/dev/null 2>&1 || (ss-redir -c /etc/shadowsocks-libev/config.json -b 0.0.0.0 -l 1080 -f /var/run/ss-redir.pid; sleep 1); cat /etc/shadowsocks-libev/community.lst /etc/shadowsocks-libev/list-general.txt /etc/shadowsocks-libev/list-google.txt /etc/shadowsocks-libev/my-domains.txt 2>/dev/null | grep -v '^#' | grep -v '^$' | sort -u > /tmp/vpn-domains.txt; awk '{print \"ipset=/\"$0\"/vpn_list\"}' /tmp/vpn-domains.txt > /tmp/dnsmasq.d/vpn-whitelist.conf; /etc/init.d/dnsmasq restart >/dev/null 2>&1; ipset create vpn_list hash:ip hashsize 65536 maxelem 131072 -exist; ipset flush vpn_list; iptables -t nat -N SS_REDIR 2>/dev/null; iptables -t nat -F SS_REDIR; iptables -t nat -D PREROUTING -p tcp -j SS_REDIR 2>/dev/null; iptables -t nat -A SS_REDIR -d %SS_SERVER% -j RETURN; iptables -t nat -A SS_REDIR -d 0.0.0.0/8 -j RETURN; iptables -t nat -A SS_REDIR -d 10.0.0.0/8 -j RETURN; iptables -t nat -A SS_REDIR -d 127.0.0.0/8 -j RETURN; iptables -t nat -A SS_REDIR -d 169.254.0.0/16 -j RETURN; iptables -t nat -A SS_REDIR -d 172.16.0.0/12 -j RETURN; iptables -t nat -A SS_REDIR -d 192.168.0.0/16 -j RETURN; iptables -t nat -A SS_REDIR -d 224.0.0.0/4 -j RETURN; iptables -t nat -A SS_REDIR -d 240.0.0.0/4 -j RETURN; iptables -t nat -A SS_REDIR -m set --match-set vpn_list dst -p tcp -j REDIRECT --to-ports 1080; iptables -t nat -A PREROUTING -p tcp -j SS_REDIR; iptables -t nat -D PREROUTING -p udp --dport 53 ! -d 192.168.8.1 -j DNAT --to-destination 192.168.8.1:53 2>/dev/null; iptables -t nat -A PREROUTING -p udp --dport 53 ! -d 192.168.8.1 -j DNAT --to-destination 192.168.8.1:53; iptables -t nat -D PREROUTING -p tcp --dport 53 ! -d 192.168.8.1 -j DNAT --to-destination 192.168.8.1:53 2>/dev/null; iptables -t nat -A PREROUTING -p tcp --dport 53 ! -d 192.168.8.1 -j DNAT --to-destination 192.168.8.1:53; iptables -D FORWARD -p udp -m set --match-set vpn_list dst -j DROP 2>/dev/null; iptables -I FORWARD -p udp -m set --match-set vpn_list dst -j DROP; for d in youtube.com googlevideo.com youtu.be discord.com instagram.com x.com tiktok.com tiktokcdn.com facebook.com google.com; do nslookup $d 127.0.0.1 >/dev/null 2>&1; done; echo 'VPN started.'"
echo.
echo ========================================
echo   VPN is ON
echo ========================================
echo.
pause
