@echo off
setlocal EnableDelayedExpansion

if not exist "%~dp0config.bat" (
    echo ERROR: config.bat not found.
    pause & exit /b 1
)
call "%~dp0config.bat"

:: Use relay if configured, otherwise direct to Amsterdam
set "HOST=%XRAY_SERVER%"
if not "%RELAY_SERVER%"=="" if not "%RELAY_SERVER%"=="YOUR_RELAY_IP" set "HOST=%RELAY_SERVER%"

:: Build VLESS+REALITY URI
:: & inside delayed-expanded variable is safe in echo with delayed expansion
set "VLESS_URL=vless://%XRAY_UUID%@!HOST!:443?security=reality^&type=tcp^&flow=xtls-rprx-vision^&sni=www.microsoft.com^&fp=chrome^&pbk=%XRAY_PUBLIC_KEY%^&sid=#RU-VPN"

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
echo   SNI         : www.microsoft.com
echo   Public Key  : %XRAY_PUBLIC_KEY%
echo   Fingerprint : chrome
echo   Short ID    : (leave empty)
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
