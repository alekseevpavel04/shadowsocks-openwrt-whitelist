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

echo [1/5] Installing packages on router...
echo       (may take 1-2 minutes)
ssh -o ConnectTimeout=10 root@%ROUTER% "grep -q 'owrt' /etc/opkg/distfeeds.conf || echo 'src/gz owrt https://downloads.openwrt.org/releases/23.05.0/packages/aarch64_cortex-a53/packages' >> /etc/opkg/distfeeds.conf; opkg update && opkg install shadowsocks-libev-ss-redir ipset && mkdir -p /etc/shadowsocks-libev"
if %errorlevel% neq 0 (
    echo       WARNING: some packages may already be installed - continuing.
) else (
    echo       OK
)
echo.

echo [2/5] Installing shadowsocks-rust (sslocal) on router...
echo       (anti-detection replacement for ss-redir)
ssh root@%ROUTER% "which sslocal >/dev/null 2>&1 && echo 'sslocal already installed, skipping.' || (opkg install xz 2>/dev/null; wget -qO /tmp/ss-rust.tar.xz https://github.com/shadowsocks/shadowsocks-rust/releases/download/v1.21.2/shadowsocks-v1.21.2.aarch64-unknown-linux-musl.tar.xz && mkdir -p /tmp/ssrust && xz -dc /tmp/ss-rust.tar.xz | tar x -C /tmp/ssrust/ && SSBIN=$(find /tmp/ssrust -name sslocal 2>/dev/null | head -1) && [ -n \"$SSBIN\" ] && cp \"$SSBIN\" /usr/bin/sslocal && chmod +x /usr/bin/sslocal && sslocal --version && echo 'installed OK') || echo 'WARN: sslocal install failed'"
echo       OK
echo.

echo [3/5] Writing Shadowsocks config to router...
echo {"server":"%SS_SERVER%","server_port":%SS_PORT%,"password":"%SS_PASSWORD%","method":"%SS_METHOD%","timeout":300}| ssh root@%ROUTER% "mkdir -p /etc/shadowsocks-libev && cat > /etc/shadowsocks-libev/config.json"
if %errorlevel% neq 0 (
    echo       FAILED
    pause
    exit /b 1
)
echo       OK
echo.

echo [4/5] Installing autostart service...
scp -O "%TEMPLATES_DIR%\shadowsocks-init.sh" root@%ROUTER%:/etc/init.d/shadowsocks
ssh root@%ROUTER% "sed -i 's/__SERVER_IP__/%SS_SERVER%/g' /etc/init.d/shadowsocks && chmod +x /etc/init.d/shadowsocks && /etc/init.d/shadowsocks enable && echo 'Service enabled.'"
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