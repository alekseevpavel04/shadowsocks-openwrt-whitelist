@echo off
echo ========================================
echo   VPN - VPS SETUP (run once on Amsterdam VPS)
echo ========================================
echo.

:: Load config
if not exist "%~dp0..\config.bat" (
    echo ERROR: config.bat not found.
    echo Copy config.example.bat to config.bat and set XRAY_SERVER.
    echo.
    pause
    exit /b 1
)
call "%~dp0..\config.bat"

if "%XRAY_SERVER%"=="YOUR_VPS_IP" (
    echo ERROR: Set XRAY_SERVER in config.bat first.
    echo.
    pause
    exit /b 1
)
if "%XRAY_SNI%"=="" (
    echo ERROR: Set XRAY_SNI in config.bat first.
    echo   Get a free subdomain at duckdns.org pointing to %XRAY_SERVER%.
    echo.
    pause
    exit /b 1
)
if "%XRAY_SNI%"=="YOUR_DOMAIN.duckdns.org" (
    echo ERROR: XRAY_SNI is still placeholder in config.bat.
    echo.
    pause
    exit /b 1
)

echo   Server: %XRAY_SERVER%
echo.
echo   This will install Xray on the VPS and print UUID + PUBLIC_KEY.
echo   After this, copy those values back into config.bat.
echo.
pause

echo [1/2] Uploading setup script to server...
scp -O "%~dp0vps-setup.sh" root@%XRAY_SERVER%:/tmp/vps-setup.sh
if %errorlevel% neq 0 (
    echo       FAILED - check that server is running and SSH works
    pause
    exit /b 1
)
echo       OK
echo.

echo [2/2] Running setup on server...
echo       (takes about 1 minute)
echo.
ssh root@%XRAY_SERVER% "XRAY_SNI=%XRAY_SNI% bash /tmp/vps-setup.sh"
if %errorlevel% neq 0 (
    echo.
    echo       FAILED - see errors above
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Done. Now:
echo   1. Copy XRAY_UUID and XRAY_PUBLIC_KEY
echo      from the output above into config.bat
echo   2. Option [B] Setup relay  (relay setup)
echo   3. Option [C] Setup router (router setup)
echo   4. Option [1] Start VPN    (start VPN)
echo ========================================
echo.
pause
