@echo off
setlocal EnableDelayedExpansion

set "T=%TEMP%\vpn_speed.txt"
set "TC=%TEMP%\vpn_speed_calc.txt"
set "VPN_IP="
set "ROUTER=192.168.8.1"

call :main
goto :cleanup

:: ============================================================
:cleanup
:: ============================================================
:: Always remove the test IP from vpn_list, even on early exit.
if not "!VPN_IP!"=="" (
    ssh -o ConnectTimeout=5 root@%ROUTER% "ipset del vpn_list !VPN_IP! 2>/dev/null" >nul 2>&1
)
del "%T%"  >nul 2>&1
del "%TC%" >nul 2>&1
echo.
pause
exit /b

:: ============================================================
:main
:: ============================================================
echo ========================================
echo   VPN - SPEED ^& BANDWIDTH TEST
echo ========================================
echo.

if not exist "%~dp0..\config.bat" (
    echo ERROR: config.bat not found.
    exit /b 1
)
call "%~dp0..\config.bat"

set "CONNECT=%XRAY_SERVER%"
set "HAS_RELAY=0"
if not "%RELAY_SERVER%"=="" if not "%RELAY_SERVER%"=="YOUR_RELAY_IP" (
    set "CONNECT=%RELAY_SERVER%"
    set "HAS_RELAY=1"
)

echo   Endpoint  : speed.cloudflare.com
echo   Test size : 25 MB download per measurement
if "!HAS_RELAY!"=="1" (
    echo   Hops      : PC -^> %RELAY_SERVER% -^> %XRAY_SERVER% -^> internet
) else (
    echo   Hops      : PC -^> %XRAY_SERVER% -^> internet
)
echo.
echo   Takes 30-90 seconds. Please wait.
echo.

:: Check that xray is running on the router (E2E test will need it)
ssh -o ConnectTimeout=8 root@%ROUTER% "pidof xray >/dev/null 2>&1 && echo RUNNING || echo STOPPED" > "%T%" 2>nul
set /p XRAY_S=<"%T%"
if not "!XRAY_S!"=="RUNNING" (
    echo   WARN: xray is NOT running on the router.
    echo         Section [3] will skip the via-VPN test. Run [1] Start VPN first.
    echo.
)

:: ============================================================
:: [1/4] Latency map
:: ============================================================
echo [1/4] Latency map (RTT per hop)
echo ----------------------------------------

:: PC -> router (LAN). .NET Ping is locale-independent (no parsing of ping text).
powershell -NoProfile -Command "$p=New-Object Net.NetworkInformation.Ping;$r=@();for($i=0;$i -lt 4;$i++){try{$r+=$p.Send('%ROUTER%',2000).RoundtripTime}catch{}};if($r.Count){'{0}ms'-f [int](($r|Measure-Object -Average).Average)}else{'FAIL'}" > "%T%" 2>nul
set /p RTT_LAN=<"%T%"
echo   PC    -^> router            : !RTT_LAN!

:: PC -> entry hop (TCP :443 handshake -- measures path including ISP)
powershell -NoProfile -Command "$sw=[Diagnostics.Stopwatch]::StartNew();$c=New-Object Net.Sockets.TcpClient;try{$c.Connect('%CONNECT%',443);$sw.Stop();'{0}ms'-f $sw.ElapsedMilliseconds}catch{'FAIL'}finally{$c.Close()}" > "%T%" 2>nul
set /p RTT_TCP=<"%T%"
echo   PC    -^> %CONNECT%:443 TCP : !RTT_TCP!

:: relay -> VPS RTT (the long-haul leg)
set "RTT_LONG=N/A"
if "!HAS_RELAY!"=="1" (
    ssh -o ConnectTimeout=8 -o BatchMode=yes root@%RELAY_SERVER% "ping -c4 -W2 %XRAY_SERVER% 2>/dev/null | tail -1 | awk -F'/' '{print int($5*10+0.5)/10 \"ms\"}'" > "%T%" 2>nul
    set /p RTT_LONG=<"%T%"
    if "!RTT_LONG!"=="" set "RTT_LONG=FAIL"
    echo   relay -^> VPS              : !RTT_LONG!
)

:: VPS -> 1.1.1.1 RTT (sanity: VPS internet quality)
ssh -o ConnectTimeout=8 -o BatchMode=yes root@%XRAY_SERVER% "ping -c4 -W2 1.1.1.1 2>/dev/null | tail -1 | awk -F'/' '{print int($5*10+0.5)/10 \"ms\"}'" > "%T%" 2>nul
set /p RTT_EXIT=<"%T%"
if "!RTT_EXIT!"=="" set "RTT_EXIT=FAIL"
echo   VPS   -^> 1.1.1.1          : !RTT_EXIT!
echo.

:: ============================================================
:: [2/4] Per-hop direct download (independent of the VPN chain)
:: ============================================================
echo [2/4] Direct uplink per hop (raw, bypasses the VPN chain)
echo ----------------------------------------

set "DL_RELAY=N/A"
if "!HAS_RELAY!"=="1" (
    echo   relay -^> Cloudflare    : downloading 25 MB...
    set "RAW="
    ssh -o ConnectTimeout=10 root@%RELAY_SERVER% "curl -s -o /dev/null -w '%%{speed_download}' --max-time 60 https://speed.cloudflare.com/__down?bytes=26214400 2>/dev/null" > "%T%" 2>nul
    set /p RAW=<"%T%"
    if not "!RAW!"=="" call :tomb "!RAW!" DL_RELAY
)

echo   VPS   -^> Cloudflare    : downloading 25 MB...
set "RAW="
ssh -o ConnectTimeout=10 root@%XRAY_SERVER% "curl -s -o /dev/null -w '%%{speed_download}' --max-time 60 https://speed.cloudflare.com/__down?bytes=26214400 2>/dev/null" > "%T%" 2>nul
set /p RAW=<"%T%"
set "DL_VPS=N/A"
if not "!RAW!"=="" call :tomb "!RAW!" DL_VPS

echo.
if "!HAS_RELAY!"=="1" echo   relay direct           : !DL_RELAY! Mbit/s
echo   VPS   direct           : !DL_VPS! Mbit/s
echo.

:: ============================================================
:: [3/4] End-to-end from this PC (bypass + via VPN)
:: ============================================================
echo [3/4] End-to-end from this PC
echo ----------------------------------------

powershell -NoProfile -Command "([Net.Dns]::GetHostAddresses('speed.cloudflare.com') | Where-Object {$_.AddressFamily -eq 'InterNetwork'} | Select-Object -First 1).IPAddressToString" > "%T%" 2>nul
set /p VPN_IP=<"%T%"
if "!VPN_IP!"=="" (
    echo   FAIL: could not resolve speed.cloudflare.com
    exit /b 1
)
echo   Pinned IP : !VPN_IP!

:: 3a. PC direct -- IP not yet in vpn_list, so traffic bypasses the router rule.
echo   PC direct (no VPN)     : downloading 25 MB...
set "RAW="
curl -s -o nul -w "%%{speed_download}" --max-time 60 --resolve speed.cloudflare.com:443:!VPN_IP! "https://speed.cloudflare.com/__down?bytes=26214400" > "%T%" 2>nul
set /p RAW=<"%T%"
set "DL_BYPASS=N/A"
if not "!RAW!"=="" call :tomb "!RAW!" DL_BYPASS

set "DL_VPN=N/A"
if "!XRAY_S!"=="RUNNING" (
    :: Add the pinned IP to vpn_list -> next request goes through full chain.
    ssh -o ConnectTimeout=8 root@%ROUTER% "ipset add vpn_list !VPN_IP! -exist" >nul 2>&1
    timeout /t 1 /nobreak >nul

    echo   PC via VPN             : downloading 25 MB...
    set "RAW="
    curl -s -o nul -w "%%{speed_download}" --max-time 90 --resolve speed.cloudflare.com:443:!VPN_IP! "https://speed.cloudflare.com/__down?bytes=26214400" > "%T%" 2>nul
    set /p RAW=<"%T%"
    if not "!RAW!"=="" call :tomb "!RAW!" DL_VPN
) else (
    echo   PC via VPN             : SKIPPED -- xray not running
    set "DL_VPN=skipped"
)

echo.
echo   PC direct (no VPN)     : !DL_BYPASS! Mbit/s
echo   PC via VPN             : !DL_VPN! Mbit/s
echo.

:: ============================================================
:: [4/4] Process & link health
:: ============================================================
echo [4/4] Process ^& link health
echo ----------------------------------------
echo   Router:
ssh -o ConnectTimeout=8 root@%ROUTER% "ps w 2>/dev/null | awk '/[x]ray run/ {print \"    xray pid=\"$1\" vsz=\"$3}' ; uptime 2>/dev/null | awk -F'load average:' '{print \"    load:\"$2}'" 2>nul

if "!HAS_RELAY!"=="1" (
    echo   Relay:
    ssh -o ConnectTimeout=8 root@%RELAY_SERVER% "C=$(ss -tn state established 2>/dev/null | grep -c '%XRAY_SERVER%') ; P=$(ps aux 2>/dev/null | grep -c '[s]ocat') ; echo \"    socat fwd to VPS: $C active\" ; echo \"    socat processes : $P (>50 = fd leak, run: systemctl restart vpn-relay)\" ; uptime 2>/dev/null | awk -F'load average:' '{print \"    load:\"$2}'" 2>nul
)

echo   VPS:
ssh -o ConnectTimeout=8 root@%XRAY_SERVER% "ps -o pcpu,pmem,comm -C xray --no-headers 2>/dev/null | awk '{print \"    xray cpu=\"$1\"%% mem=\"$2\"%%\"}' ; uptime 2>/dev/null | awk -F'load average:' '{print \"    load:\"$2}'" 2>nul
echo.

:: ============================================================
:: Summary
:: ============================================================
echo ========================================
echo   SUMMARY
echo ========================================
echo   Latency:
echo     PC    -^> router       : !RTT_LAN!
echo     PC    -^> entry :443   : !RTT_TCP!
if "!HAS_RELAY!"=="1" echo     relay -^> VPS         : !RTT_LONG!
echo     VPS   -^> 1.1.1.1      : !RTT_EXIT!
echo.
echo   Bandwidth:
if "!HAS_RELAY!"=="1" echo     relay direct DL      : !DL_RELAY! Mbit/s
echo     VPS   direct DL      : !DL_VPS! Mbit/s
echo     PC direct DL         : !DL_BYPASS! Mbit/s
echo     PC via VPN DL        : !DL_VPN! Mbit/s
echo ========================================
echo.
echo   How to read this:
echo.
echo   * VPS direct ^>^> PC via VPN
echo     -^> Bottleneck is the long-haul relay-^>VPS link or REALITY/CPU on router.
echo.
echo   * relay direct ^>^> VPS direct
echo     -^> Cloudflare-Vultr peering or VPS uplink shaping.
echo.
echo   * PC direct ^>^> PC via VPN
echo     -^> Normal VPN overhead (20-50%% loss is OK).
echo.
echo   * All numbers low at the same time
echo     -^> Local ISP congestion / time-of-day shaping. Try at a different hour.
echo.
exit /b

:: ============================================================
:: Helper: convert raw bytes/sec to Mbit/s with 1 decimal,
:: locale-independent (InvariantCulture forces "." not ",").
::   %~1 = raw bytes/sec, %2 = output variable name
:: ============================================================
:tomb
set "_MB="
powershell -NoProfile -Command "[string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:F1}', %~1*8/1000000)" > "%TC%" 2>nul
set /p _MB=<"%TC%"
del "%TC%" >nul 2>&1
if "!_MB!"=="" set "_MB=N/A"
set "%2=!_MB!"
exit /b
