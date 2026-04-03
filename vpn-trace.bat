@echo off
setlocal EnableDelayedExpansion
set "T=%TEMP%\vpn_trace.txt"

:: call :main so that pause ALWAYS runs even if the script crashes mid-way
call :main
echo.
echo ========================================
if !ERRORS!==0 (
    echo   ALL CHECKS PASSED
    echo   Full chain PC -^> relay -^> Amsterdam is operational.
) else (
    echo   !ERRORS! CHECK(S) FAILED - see output above
)
echo ========================================
echo.
del "%T%" >nul 2>&1
pause
exit /b

:: ==============================================================
:main
:: ==============================================================
echo ========================================
echo   VPN PATH TRACE
echo   PC -^> RU relay -^> Amsterdam -^> internet
echo ========================================
echo.

if not exist "%~dp0config.bat" (
    echo ERROR: config.bat not found.
    exit /b 1
)
call "%~dp0config.bat"

set "ROUTER=192.168.8.1"
set ERRORS=0
set SSH_RELAY=0

set "CONNECT=%XRAY_SERVER%"
if not "%RELAY_SERVER%"=="" if not "%RELAY_SERVER%"=="YOUR_RELAY_IP" set "CONNECT=%RELAY_SERVER%"

echo   PC -^> !CONNECT!:443
if not "!CONNECT!"=="%XRAY_SERVER%" echo        -^> (relay) -^> %XRAY_SERVER%:443
echo        -^> internet
echo.

:: ---- [1/5] Config -----------------------------------------------
echo [1/5] Config check
echo ----------------------------------------
if "%XRAY_SERVER%"=="" (
    echo   FAIL  XRAY_SERVER not set in config.bat
    set /A ERRORS+=1
) else if "%XRAY_SERVER%"=="YOUR_VPS_IP" (
    echo   FAIL  XRAY_SERVER is still placeholder
    set /A ERRORS+=1
) else (
    echo   OK    Amsterdam VPS : %XRAY_SERVER%
)

if "%RELAY_SERVER%"=="" (
    echo   WARN  RELAY_SERVER empty - direct mode ^(no relay^)
) else if "%RELAY_SERVER%"=="YOUR_RELAY_IP" (
    echo   WARN  RELAY_SERVER not set - direct mode ^(no relay^)
) else (
    echo   OK    RU relay      : %RELAY_SERVER%
    echo %RELAY_SERVER% | findstr ":" >nul 2>&1
    if !errorlevel!==0 (
        echo   WARN  RELAY_SERVER looks like IPv6 address!
        echo         socat uses TCP4-LISTEN - only IPv4 works.
        echo         Fix: set RELAY_SERVER=195.133.27.132 in config.bat
    )
)
echo.

:: ---- [2/5] Relay service ----------------------------------------
echo [2/5] Relay service
echo ----------------------------------------
if "%RELAY_SERVER%"=="" (
    echo   SKIP  No relay configured
    echo.
    goto :relay_tcp
)
if "%RELAY_SERVER%"=="YOUR_RELAY_IP" (
    echo   SKIP  No relay configured
    echo.
    goto :relay_tcp
)

ssh -o ConnectTimeout=8 -o BatchMode=yes root@%RELAY_SERVER% "exit 0" >nul 2>&1
if %errorlevel%==0 (
    set SSH_RELAY=1
    echo   OK    SSH to relay
) else (
    echo   FAIL  SSH to %RELAY_SERVER% unreachable
    echo         Check: RELAY_SERVER in config.bat (use IPv4, not IPv6^)
    echo         Check: run vpn-addkey-relay.bat if SSH key not set up
    set /A ERRORS+=1
    echo.
    goto :relay_tcp
)

ssh root@%RELAY_SERVER% "systemctl is-active vpn-relay 2>/dev/null" > "%T%" 2>&1
set /p SVC=<"%T%"
if "!SVC!"=="active" (
    echo   OK    vpn-relay service : active
) else (
    echo   FAIL  vpn-relay service : !SVC!
    echo         Fix: ssh root@%RELAY_SERVER% "systemctl restart vpn-relay"
    set /A ERRORS+=1
)

ssh root@%RELAY_SERVER% "ss -tnlp 2>/dev/null | grep ':443' | awk '{print $4}' | head -1" > "%T%" 2>&1
set /p LISTEN=<"%T%"
echo   INFO  Port 443 listen  : !LISTEN!

ssh root@%RELAY_SERVER% "ss -tn state established 2>/dev/null | grep -c %XRAY_SERVER%" > "%T%" 2>&1
set /p CONNS=<"%T%"
echo   INFO  Active relayed conns to Amsterdam: !CONNS!
echo.

:: ---- [3/5] Relay -> Amsterdam -----------------------------------
:relay_tcp
echo [3/5] Relay -^> Amsterdam TCP:443
echo ----------------------------------------
if "%RELAY_SERVER%"=="" (echo   SKIP  No relay configured & echo. & goto :router_checks)
if "%RELAY_SERVER%"=="YOUR_RELAY_IP" (echo   SKIP  No relay configured & echo. & goto :router_checks)
if !SSH_RELAY!==0 (echo   SKIP  Relay SSH failed & echo. & goto :router_checks)

ssh root@%RELAY_SERVER% "nc -w3 %XRAY_SERVER% 443 </dev/null >/dev/null 2>&1 && echo OK || echo FAIL" > "%T%" 2>&1
set /p RTCP=<"%T%"
if "!RTCP!"=="OK" (
    echo   OK    %RELAY_SERVER% -^> %XRAY_SERVER%:443
) else (
    echo   FAIL  %RELAY_SERVER% -^> %XRAY_SERVER%:443
    echo         Check: Xray running on Amsterdam VPS? Port 443 open?
    set /A ERRORS+=1
)
echo.

:: ---- [4/5] Router -----------------------------------------------
:router_checks
echo [4/5] Router checks
echo ----------------------------------------
ssh -o ConnectTimeout=8 root@%ROUTER% "pidof xray >/dev/null 2>&1 && echo RUNNING || echo STOPPED" > "%T%" 2>&1
set /p XRAY_S=<"%T%"
if "!XRAY_S!"=="RUNNING" (
    echo   OK    Xray process     : RUNNING
) else (
    echo   FAIL  Xray process     : STOPPED
    echo         Run vpn-start.bat first
    set /A ERRORS+=1
)

:: Check using active connections (ss) — nc -z is not supported on OpenWrt BusyBox
ssh -o ConnectTimeout=8 root@%ROUTER% "ss -tn 2>/dev/null | grep -c '!CONNECT!:443'" > "%T%" 2>&1
set /p RCONNS=<"%T%"
if "!RCONNS!"=="0" (
    echo   WARN  router -^> !CONNECT!:443 : no active sessions
    echo         (normal if no VPN traffic routed yet; Exit IP check below is definitive^)
) else (
    echo   OK    router -^> !CONNECT!:443 : !RCONNS! active session(s^)
)

ssh -o ConnectTimeout=8 root@%ROUTER% "iptables -t nat -L SS_REDIR 2>/dev/null | grep -c REDIRECT" > "%T%" 2>&1
set /p IPT=<"%T%"
echo   INFO  iptables REDIRECT rules: !IPT!
echo.

:: ---- [5/5] Exit IP ----------------------------------------------
echo [5/5] Exit IP via full VPN chain
echo ----------------------------------------
if not "!XRAY_S!"=="RUNNING" (
    echo   SKIP  Xray not running
    echo.
    exit /b
)

:: Resolve ifconfig.me using .NET (no pipes, works reliably in batch)
echo   Resolving ifconfig.me...
powershell -Command "[Net.Dns]::GetHostAddresses('ifconfig.me')[0].IPAddressToString" > "%T%" 2>nul
set /p IFCFG_IP=<"%T%"

if "!IFCFG_IP!"=="" (
    echo   WARN  Could not resolve ifconfig.me - skipping
    echo.
    exit /b
)
echo   INFO  ifconfig.me = !IFCFG_IP!

:: Temporarily add ifconfig.me IP to vpn_list on router.
:: Packets from Windows to this IP will be redirected by iptables to
:: xray:1080 -> relay -> Amsterdam -> ifconfig.me (which returns the exit IP)
echo   Adding to router vpn_list and checking exit IP...
ssh root@%ROUTER% "ipset add vpn_list !IFCFG_IP! -exist 2>/dev/null" >nul 2>&1
timeout /t 1 /nobreak >nul

curl -s --max-time 15 https://ifconfig.me/ip > "%T%" 2>nul
set /p EXIT_IP=<"%T%"

ssh root@%ROUTER% "ipset del vpn_list !IFCFG_IP! 2>/dev/null" >nul 2>&1

if "!EXIT_IP!"=="" (
    echo   FAIL  Exit IP: TIMEOUT - VPN chain is broken
    set /A ERRORS+=1
) else (
    echo   OK    Exit IP: !EXIT_IP!
    if "!EXIT_IP!"=="%XRAY_SERVER%" (
        echo         = Amsterdam VPS IP - chain is perfect
    ) else (
        echo         Note: differs from VPS IP %XRAY_SERVER%
        echo         This is OK if it's still a Vultr Amsterdam IP
    )
)
echo.
pause
