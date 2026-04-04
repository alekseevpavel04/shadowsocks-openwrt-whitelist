@echo off
echo ========================================
echo   VPN - RELAY SETUP (run once on Timeweb)
echo ========================================
echo.

:: Load config
if not exist "%~dp0..\config.bat" (
    echo ERROR: config.bat not found.
    pause
    exit /b 1
)
call "%~dp0..\config.bat"

if "%RELAY_SERVER%"=="" (
    echo ERROR: Set RELAY_SERVER in config.bat first.
    pause
    exit /b 1
)
if "%RELAY_SERVER%"=="YOUR_RELAY_IP" (
    echo ERROR: Set RELAY_SERVER in config.bat first.
    pause
    exit /b 1
)

echo   Relay  : %RELAY_SERVER%
echo   Target : %XRAY_SERVER%:443
echo.
echo   This will install socat relay on the Timeweb VPS.
echo   Traffic arriving at %RELAY_SERVER%:443 will be
echo   forwarded to %XRAY_SERVER%:443 (Amsterdam VPS).
echo.
pause

echo [1/2] Uploading relay setup script...
scp -O "%~dp0relay-setup.sh" root@%RELAY_SERVER%:/tmp/relay-setup.sh
if %errorlevel% neq 0 (
    echo       FAILED - check SSH access (run option [9] SSH key for relay first)
    pause
    exit /b 1
)
echo       OK
echo.

echo [2/2] Running setup on relay server...
echo       (takes about 30 seconds)
echo.
ssh root@%RELAY_SERVER% "XRAY_SERVER=%XRAY_SERVER% bash /tmp/relay-setup.sh"
if %errorlevel% neq 0 (
    echo.
    echo       FAILED - see errors above
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Done.
echo   Run option [1] Start VPN to apply.
echo ========================================
echo.
pause
