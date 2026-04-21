@echo off
setlocal EnableDelayedExpansion

if not exist "%~dp0..\config.bat" (
    echo ERROR: config.bat not found.
    pause & exit /b 1
)
call "%~dp0..\config.bat"

:: Use relay if configured, otherwise direct to Amsterdam
set "HOST=%XRAY_SERVER%"
if not "%RELAY_SERVER%"=="" if not "%RELAY_SERVER%"=="YOUR_RELAY_IP" set "HOST=%RELAY_SERVER%"

:: Build VLESS+REALITY URI
:: & inside delayed-expanded variable is safe in echo with delayed expansion
set "VLESS_URL=vless://%XRAY_UUID%@!HOST!:443?security=reality^&type=tcp^&flow=xtls-rprx-vision^&sni=%XRAY_SNI%^&fp=chrome^&pbk=%XRAY_PUBLIC_KEY%^&sid=%XRAY_SHORT_ID%#RU-VPN"

echo ========================================
echo   SECURITY WARNING (April 2026)
echo ========================================
echo   All Android VLESS clients (v2rayNG, NekoBox,
echo   Hiddify, Happ) currently contain a known
echo   vulnerability: an unauthenticated localhost
echo   SOCKS5 proxy. Spy modules embedded in Russian
echo   apps (Yandex / MAX / Sber / Gosuslugi /
echo   Wildberries / Ozon) can connect to it directly,
echo   bypass per-app split tunneling, and learn the
echo   exit IP of your VPN.
echo.
echo   Recommendations:
echo   - PREFER connecting through this router's wifi
echo     instead of running a VPN client directly on
echo     the phone.
echo   - iOS Shadowrocket is not on the published list
echo     of vulnerable clients, but it is closed source
echo     -- no guarantees. Keep it updated.
echo   - Do NOT install a VLESS client on a phone that
echo     also has Yandex / MAX / Sber / Gosuslugi /
echo     Wildberries / Ozon installed.
echo   - Source: runetfreedom on Habr, April 2026.
echo ========================================
echo.
echo ========================================
echo   SHADOWROCKET / v2rayNG CONFIG
echo   Server: !HOST!:443
echo ========================================
echo.
echo   --- Manual entry ---
echo.
echo   Protocol    : VLESS
echo   Address     : !HOST!
echo   Port        : 443
echo   UUID        : %XRAY_UUID%
echo   Flow        : xtls-rprx-vision
echo   Network     : TCP
echo   Security    : Reality
echo   SNI         : %XRAY_SNI%
echo   Public Key  : %XRAY_PUBLIC_KEY%
echo   Fingerprint : chrome
echo   Short ID    : %XRAY_SHORT_ID%
echo.
echo ========================================
echo   --- Import URL ---
echo   In Shadowrocket: + -^> URL
echo   In v2rayNG: +    -^> Import from clipboard
echo ========================================
echo.
echo !VLESS_URL!
echo.

:: Copy URL to clipboard so you can AirDrop / paste
powershell -Command "Set-Clipboard '!VLESS_URL!'"
echo   (URL copied to clipboard)
echo.
pause
