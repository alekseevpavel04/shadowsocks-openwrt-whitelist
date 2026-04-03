@echo off
echo ========================================
echo   VPN - FIRST TIME SETUP (router)
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

if "%XRAY_SERVER%"=="YOUR_VPS_IP" (
    echo ERROR: config.bat has not been filled in.
    echo Run vpn-server-setup.bat first, then fill in config.bat.
    echo.
    pause
    exit /b 1
)

set "ROUTER=192.168.8.1"
set "LISTS_DIR=%~dp0lists"
set "TEMPLATES_DIR=%~dp0templates"

:: Use relay if configured, otherwise connect directly to Amsterdam VPS
set "CONNECT_SERVER=%XRAY_SERVER%"
if not "%RELAY_SERVER%"=="" if not "%RELAY_SERVER%"=="YOUR_RELAY_IP" set "CONNECT_SERVER=%RELAY_SERVER%"

echo   Router : %ROUTER%
echo   Server : %CONNECT_SERVER%:443
echo.

echo [1/4] Installing dependencies on router...
ssh -o ConnectTimeout=10 root@%ROUTER% "opkg update && opkg install ipset unzip"
if %errorlevel% neq 0 (
    echo       WARNING: some packages may already be installed - continuing.
) else (
    echo       OK
)
echo.

echo [2/4] Installing Xray on router...
echo       (downloading arm64 binary, ~10 MB)
ssh root@%ROUTER% "[ -x /usr/local/bin/xray ] && /usr/local/bin/xray version && echo 'xray already installed, skipping.' || (wget -qO /tmp/xray.zip 'https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip' && mkdir -p /tmp/xray && unzip -o /tmp/xray.zip xray -d /tmp/xray/ && cp /tmp/xray/xray /usr/local/bin/xray && chmod +x /usr/local/bin/xray && /usr/local/bin/xray version && echo 'installed OK')"
if %errorlevel% neq 0 (
    echo       FAILED
    pause
    exit /b 1
)
echo       OK
echo.

echo [3/4] Uploading xray config to router...
set "TMPCONFIG=%TEMP%\xray-router.json"
powershell -Command "$c=(Get-Content '%TEMPLATES_DIR%\xray-router.json') -replace '__SERVER_IP__','%CONNECT_SERVER%' -replace '__UUID__','%XRAY_UUID%' -replace '__PUBLIC_KEY__','%XRAY_PUBLIC_KEY%'; [System.IO.File]::WriteAllLines('%TMPCONFIG%',$c)"
ssh root@%ROUTER% "mkdir -p /etc/xray"
scp -O "%TMPCONFIG%" root@%ROUTER%:/etc/xray/config.json
if %errorlevel% neq 0 (
    echo       FAILED
    pause
    exit /b 1
)
echo       OK
echo.

echo [4/4] Installing autostart service...
scp -O "%TEMPLATES_DIR%\shadowsocks-init.sh" root@%ROUTER%:/etc/init.d/shadowsocks
ssh root@%ROUTER% "sed -i 's/__SERVER_IP__/%CONNECT_SERVER%/g' /etc/init.d/shadowsocks && chmod +x /etc/init.d/shadowsocks && /etc/init.d/shadowsocks enable && echo 'Service enabled.'"
if %errorlevel% neq 0 (
    echo       FAILED
    pause
    exit /b 1
)
echo       OK
echo.

echo [5/5] Uploading domain lists...
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
