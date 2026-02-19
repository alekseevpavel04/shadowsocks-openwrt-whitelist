@echo off
echo ========================================
echo   VPN - FIRST TIME SETUP
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

if "%SS_SERVER%"=="YOUR_SERVER_IP" (
    echo ERROR: config.bat has not been filled in.
    echo Open config.bat and set SS_SERVER, SS_PORT, SS_PASSWORD, SS_METHOD.
    echo.
    pause
    exit /b 1
)

set "ROUTER=192.168.8.1"
set "LISTS_DIR=%~dp0lists"
set "TEMPLATES_DIR=%~dp0templates"

echo   Router : %ROUTER%
echo   Server : %SS_SERVER%:%SS_PORT%
echo   Method : %SS_METHOD%
echo.

echo [1/4] Installing packages on router...
echo       (may take 1-2 minutes)
ssh -o ConnectTimeout=10 root@%ROUTER% "opkg update && opkg install shadowsocks-libev-ss-redir ipset"
if %errorlevel% neq 0 (
    echo       WARNING: some packages may already be installed - continuing.
) else (
    echo       OK
)
echo.

echo [2/4] Writing Shadowsocks config to router...
echo {"server":"%SS_SERVER%","server_port":%SS_PORT%,"password":"%SS_PASSWORD%","method":"%SS_METHOD%","local_address":"0.0.0.0","local_port":1080,"timeout":300}| ssh root@%ROUTER% "cat > /etc/shadowsocks-libev/config.json"
if %errorlevel% neq 0 (
    echo       FAILED
    pause
    exit /b 1
)
echo       OK
echo.

echo [3/4] Installing autostart service...
scp -O "%TEMPLATES_DIR%\shadowsocks-init.sh" root@%ROUTER%:/etc/init.d/shadowsocks
ssh root@%ROUTER% "sed -i 's/__SERVER_IP__/%SS_SERVER%/g' /etc/init.d/shadowsocks && chmod +x /etc/init.d/shadowsocks && /etc/init.d/shadowsocks enable && echo 'Service enabled.'"
if %errorlevel% neq 0 (
    echo       FAILED
    pause
    exit /b 1
)
echo       OK
echo.

echo [4/4] Uploading domain lists...
if exist "%LISTS_DIR%\list-general.txt" (
    scp -O "%LISTS_DIR%\community.lst" "%LISTS_DIR%\list-general.txt" "%LISTS_DIR%\list-google.txt" "%LISTS_DIR%\my-domains.txt" root@%ROUTER%:/etc/shadowsocks-libev/ 2>nul
    echo       OK
) else (
    echo       Lists not found - run vpn-update.bat first to download them.
)
echo.

echo ========================================
echo   Setup complete!
echo.
echo   Next steps:
echo   1. vpn-update.bat  (if lists were not uploaded)
echo   2. vpn-start.bat   (enable VPN)
echo ========================================
echo.
pause
