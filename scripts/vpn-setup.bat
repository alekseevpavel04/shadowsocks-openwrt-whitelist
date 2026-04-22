@echo off
echo ========================================
echo   VPN - ROUTER SETUP (one-time)
echo ========================================
echo.

if not exist "%~dp0..\config.bat" (echo ERROR: config.bat not found & pause & exit /b 1)
call "%~dp0..\config.bat"

if "%RELAY_SERVER%"=="" (echo ERROR: RELAY_SERVER not set - run [B] Setup relay first & pause & exit /b 1)
if "%RELAY_SERVER%"=="YOUR_RELAY_IP" (echo ERROR: RELAY_SERVER placeholder & pause & exit /b 1)
if "%RELAY_UUID%"=="YOUR_RELAY_UUID" (echo ERROR: RELAY_UUID placeholder - run [B] Setup relay first & pause & exit /b 1)
if "%RELAY_UUID%"=="" (echo ERROR: RELAY_UUID not set & pause & exit /b 1)
if "%RELAY_PUBLIC_KEY%"=="YOUR_RELAY_PUBLIC_KEY" (echo ERROR: RELAY_PUBLIC_KEY placeholder & pause & exit /b 1)
if "%RELAY_SHORT_ID%"=="YOUR_RELAY_SHORT_ID" (echo ERROR: RELAY_SHORT_ID placeholder & pause & exit /b 1)

set "ROUTER=192.168.8.1"
set "LISTS_DIR=%~dp0..\lists"
set "TEMPLATES_DIR=%~dp0..\templates"

echo   Router -^> relay %RELAY_SERVER%:443
echo.

echo [1/5] Installing dependencies on router...
ssh -o ConnectTimeout=10 root@%ROUTER% "opkg update && opkg install ipset unzip"
if %errorlevel% neq 0 echo       WARNING: some packages may already be installed - continuing.
echo.

echo [2/5] Installing Xray on router...
ssh root@%ROUTER% "[ -x /usr/local/bin/xray ] && /usr/local/bin/xray version && echo 'xray already installed, skipping.' || (wget -qO /tmp/xray.zip 'https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip' && mkdir -p /tmp/xray && unzip -o /tmp/xray.zip xray -d /tmp/xray/ && cp /tmp/xray/xray /usr/local/bin/xray && chmod +x /usr/local/bin/xray && /usr/local/bin/xray version && echo 'installed OK')"
if %errorlevel% neq 0 (echo       FAILED & pause & exit /b 1)
echo       OK
echo.

echo [3/5] Uploading xray config to router...
set "TMPCONFIG=%TEMP%\xray-router.json"
powershell -Command "$c=(Get-Content '%TEMPLATES_DIR%\xray-router.json') -replace '__SERVER_IP__','%RELAY_SERVER%' -replace '__UUID__','%RELAY_UUID%' -replace '__PUBLIC_KEY__','%RELAY_PUBLIC_KEY%' -replace '__SHORT_ID__','%RELAY_SHORT_ID%' -replace '__SNI__','%RELAY_SNI%'; [System.IO.File]::WriteAllLines('%TMPCONFIG%',$c)"
ssh root@%ROUTER% "mkdir -p /etc/xray"
scp -O "%TMPCONFIG%" root@%ROUTER%:/etc/xray/config.json
if %errorlevel% neq 0 (echo       FAILED & pause & exit /b 1)
echo       OK
echo.

echo [4/5] Installing autostart service...
scp -O "%TEMPLATES_DIR%\vpn-init.sh" root@%ROUTER%:/etc/init.d/shadowsocks
ssh root@%ROUTER% "sed -i 's/__SERVER_IP__/%RELAY_SERVER%/g' /etc/init.d/shadowsocks && chmod +x /etc/init.d/shadowsocks && /etc/init.d/shadowsocks enable && echo 'Service enabled.'"
if %errorlevel% neq 0 (echo       FAILED & pause & exit /b 1)
echo       OK
echo.

echo [5/5] Uploading domain lists...
ssh root@%ROUTER% "mkdir -p /etc/shadowsocks-libev"
if exist "%LISTS_DIR%\list-general.txt" (
    scp -O "%LISTS_DIR%\community.lst" "%LISTS_DIR%\list-general.txt" "%LISTS_DIR%\list-google.txt" "%LISTS_DIR%\my-domains.txt" root@%ROUTER%:/etc/shadowsocks-libev/ 2>nul
    echo       OK
) else (
    echo       Lists not found - run option [3] Update lists first.
)
echo.

echo ========================================
echo   Setup complete. Run option [1] Start VPN.
echo ========================================
echo.
pause
