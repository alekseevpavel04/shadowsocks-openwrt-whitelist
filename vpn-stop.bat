@echo off

echo ========================================
echo   VPN - STOP
echo ========================================
echo.

set "ROUTER=192.168.8.1"

echo Stopping VPN...
ssh root@%ROUTER% "killall ss-redir 2>/dev/null; iptables -t nat -D PREROUTING -p tcp -j SS_REDIR 2>/dev/null; iptables -t nat -F SS_REDIR 2>/dev/null; iptables -t nat -X SS_REDIR 2>/dev/null; ipset flush vpn_list 2>/dev/null; rm -f /tmp/dnsmasq.d/vpn-whitelist.conf; /etc/init.d/dnsmasq restart >/dev/null 2>&1; echo 'VPN stopped.'"

echo.
echo ========================================
echo   VPN is OFF
echo ========================================
echo.
pause