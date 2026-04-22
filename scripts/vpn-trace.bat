@echo off
setlocal EnableDelayedExpansion
set "T=%TEMP%\vpn_trace.txt"
call :main
echo.
echo ========================================
if !ERRORS!==0 (
    echo   ALL CHECKS PASSED
) else (
    echo   !ERRORS! CHECK(S) FAILED - see above
)
echo ========================================
del "%T%" >nul 2>&1
pause
exit /b

:main
echo ========================================
echo   VPN PATH TRACE (router -^> relay -^> VPS)
echo ========================================
echo.

if not exist "%~dp0..\config.bat" (echo ERROR: config.bat not found & exit /b 1)
call "%~dp0..\config.bat"

set "ROUTER=192.168.8.1"
set ERRORS=0

echo [1/5] Config
echo ----------------------------------------
if "%VPS_SERVER%"=="" (echo   FAIL  VPS_SERVER not set & set /A ERRORS+=1) else (echo   OK    VPS    : %VPS_SERVER% ^(SNI %VPS_SNI%^))
if "%RELAY_SERVER%"=="" (echo   FAIL  RELAY_SERVER not set & set /A ERRORS+=1) else (echo   OK    Relay  : %RELAY_SERVER% ^(SNI %RELAY_SNI%^))
echo.

echo [2/5] Relay Xray service
echo ----------------------------------------
ssh -o ConnectTimeout=8 -o BatchMode=yes root@%RELAY_SERVER% "systemctl is-active xray 2>/dev/null" > "%T%" 2>&1
set /p SVC=<"%T%"
if "!SVC!"=="active" (echo   OK    xray on relay: active) else (echo   FAIL  xray on relay: !SVC! & set /A ERRORS+=1)
ssh root@%RELAY_SERVER% "ss -tn state established 2>/dev/null | grep -c %VPS_SERVER%" > "%T%" 2>&1
set /p CONNS=<"%T%"
echo   INFO  Active relay-^>VPS conns: !CONNS!
echo.

echo [3/5] VPS Xray service
echo ----------------------------------------
ssh -o ConnectTimeout=8 -o BatchMode=yes root@%VPS_SERVER% "systemctl is-active xray 2>/dev/null" > "%T%" 2>&1
set /p SVC=<"%T%"
if "!SVC!"=="active" (echo   OK    xray on VPS: active) else (echo   FAIL  xray on VPS: !SVC! & set /A ERRORS+=1)
echo.

echo [4/5] Router Xray
echo ----------------------------------------
ssh -o ConnectTimeout=8 root@%ROUTER% "pidof xray >/dev/null 2>&1 && echo RUNNING || echo STOPPED" > "%T%" 2>&1
set /p XRAY_S=<"%T%"
if "!XRAY_S!"=="RUNNING" (echo   OK    xray on router: running) else (echo   FAIL  xray on router: stopped & set /A ERRORS+=1)
ssh -o ConnectTimeout=8 root@%ROUTER% "grep -c 'received real certificate' /tmp/xray.log 2>/dev/null" > "%T%" 2>&1
set /p CERT_ERRS=<"%T%"
if "!CERT_ERRS!"=="0" (echo   OK    no REALITY handshake errors) else (echo   WARN  %CERT_ERRS% REALITY 'real certificate' lines - check credentials)
echo.

echo [5/5] Exit IP through full chain
echo ----------------------------------------
if not "!XRAY_S!"=="RUNNING" (echo   SKIP  Xray not running & exit /b)
powershell -Command "[Net.Dns]::GetHostAddresses('ifconfig.me')[0].IPAddressToString" > "%T%" 2>nul
set /p IFCFG_IP=<"%T%"
if "!IFCFG_IP!"=="" (echo   WARN  Could not resolve ifconfig.me & exit /b)
ssh root@%ROUTER% "ipset add vpn_list !IFCFG_IP! -exist 2>/dev/null" >nul 2>&1
timeout /t 1 /nobreak >nul
curl -s --max-time 15 https://ifconfig.me/ip > "%T%" 2>nul
set /p EXIT_IP=<"%T%"
ssh root@%ROUTER% "ipset del vpn_list !IFCFG_IP! 2>/dev/null" >nul 2>&1
if "!EXIT_IP!"=="" (echo   FAIL  Exit IP: TIMEOUT - chain is broken & set /A ERRORS+=1) else (
    echo   OK    Exit IP: !EXIT_IP!
    if "!EXIT_IP!"=="%VPS_SERVER%" (echo         = VPS IP - chain perfect) else (echo         Note: differs from VPS %VPS_SERVER%)
)
echo.
exit /b
