@echo off
echo ========================================
echo   VPS SETUP (VLESS+REALITY egress)
echo ========================================
echo.

if not exist "%~dp0..\config.bat" (
    echo ERROR: config.bat not found.
    echo Copy config.example.bat to config.bat and set VPS_SERVER.
    pause & exit /b 1
)
call "%~dp0..\config.bat"

if "%VPS_SERVER%"=="" (echo ERROR: Set VPS_SERVER in config.bat & pause & exit /b 1)
if "%VPS_SERVER%"=="YOUR_VPS_IP" (echo ERROR: VPS_SERVER is placeholder in config.bat & pause & exit /b 1)

:: Auto-derive SNI if user left placeholder
set "VPS_SNI_EFFECTIVE=%VPS_SNI%"
if "%VPS_SNI_EFFECTIVE%"=="" set "VPS_SNI_EFFECTIVE=%VPS_SERVER%.sslip.io"
if "%VPS_SNI_EFFECTIVE%"=="YOUR_VPS_IP.sslip.io" set "VPS_SNI_EFFECTIVE=%VPS_SERVER%.sslip.io"

echo   VPS IP  : %VPS_SERVER%
echo   VPS SNI : %VPS_SNI_EFFECTIVE%
echo.
echo   This wipes any old Xray config on %VPS_SERVER% and sets up a fresh
echo   VLESS+REALITY egress inbound on :443. New UUID + keys are generated.
echo.
pause

echo [1/3] Wiping old VPS config...
ssh root@%VPS_SERVER% "systemctl stop xray 2>/dev/null; rm -f /usr/local/etc/xray/config.json; echo wiped"
echo       OK
echo.

echo [2/3] Uploading setup script...
scp -O "%~dp0vps-setup.sh" root@%VPS_SERVER%:/tmp/vps-setup.sh
if %errorlevel% neq 0 (echo       FAILED & pause & exit /b 1)
echo       OK
echo.

echo [3/3] Running setup on VPS...
ssh root@%VPS_SERVER% "VPS_SNI=%VPS_SNI_EFFECTIVE% bash /tmp/vps-setup.sh"
if %errorlevel% neq 0 (echo       FAILED - see output above & pause & exit /b 1)

echo.
echo ========================================
echo   Next: paste VPS_UUID / VPS_PUBLIC_KEY / VPS_SHORT_ID / VPS_SNI
echo   shown above into config.bat, then run option [B] Setup relay.
echo ========================================
echo.
pause
