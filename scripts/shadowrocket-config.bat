@echo off
setlocal EnableDelayedExpansion

if not exist "%~dp0..\config.bat" (echo ERROR: config.bat not found & pause & exit /b 1)
call "%~dp0..\config.bat"

:: Phone connects to RELAY (same ingress as router)
if "%RELAY_SERVER%"=="" (echo ERROR: RELAY_SERVER not set & pause & exit /b 1)
if "%RELAY_SERVER%"=="YOUR_RELAY_IP" (echo ERROR: run option [B] Setup relay first & pause & exit /b 1)
if "%RELAY_UUID%"=="YOUR_RELAY_UUID" (echo ERROR: run option [B] Setup relay first & pause & exit /b 1)

set "VLESS_URL=vless://%RELAY_UUID%@%RELAY_SERVER%:443?security=reality^&type=tcp^&flow=xtls-rprx-vision^&sni=%RELAY_SNI%^&fp=chrome^&pbk=%RELAY_PUBLIC_KEY%^&sid=%RELAY_SHORT_ID%#RU-VPN"

echo ========================================
echo   SECURITY WARNING (April 2026)
echo ========================================
echo   All Android VLESS clients (v2rayNG, NekoBox,
echo   Hiddify, Happ) currently contain a known
echo   vulnerability: an unauthenticated localhost
echo   SOCKS5 proxy. Spy modules embedded in Russian
echo   apps (Yandex / MAX / Sber / Gosuslugi /
echo   Wildberries / Ozon) can connect to it and learn
echo   the exit IP of your VPN.
echo.
echo   Recommendations:
echo   - PREFER connecting through this router's wifi
echo     instead of running a VPN client on the phone.
echo   - Do NOT install a VLESS client on a phone that
echo     also has Yandex / MAX / Sber / Gosuslugi /
echo     Wildberries / Ozon installed.
echo ========================================
echo.
echo ========================================
echo   SHADOWROCKET / v2rayNG CONFIG
echo   Server: %RELAY_SERVER%:443 (relay, SPB)
echo ========================================
echo.
echo   Protocol    : VLESS
echo   Address     : %RELAY_SERVER%
echo   Port        : 443
echo   UUID        : %RELAY_UUID%
echo   Flow        : xtls-rprx-vision
echo   Network     : TCP
echo   Security    : Reality
echo   SNI         : %RELAY_SNI%
echo   Public Key  : %RELAY_PUBLIC_KEY%
echo   Fingerprint : chrome
echo   Short ID    : %RELAY_SHORT_ID%
echo.
echo ========================================
echo   Import URL (also copied to clipboard):
echo ========================================
echo.
echo %VLESS_URL%
echo.

powershell -Command "Set-Clipboard '!VLESS_URL!'"
echo   (URL copied to clipboard)
echo.
pause
