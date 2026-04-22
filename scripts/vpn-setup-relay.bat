@echo off
echo ========================================
echo   RELAY SETUP (VLESS+REALITY ingress, chains to VPS)
echo ========================================
echo.

if not exist "%~dp0..\config.bat" (echo ERROR: config.bat not found & pause & exit /b 1)
call "%~dp0..\config.bat"

if "%RELAY_SERVER%"=="" (echo ERROR: Set RELAY_SERVER in config.bat & pause & exit /b 1)
if "%RELAY_SERVER%"=="YOUR_RELAY_IP" (echo ERROR: RELAY_SERVER placeholder & pause & exit /b 1)

if "%VPS_SERVER%"=="YOUR_VPS_IP" (echo ERROR: VPS_SERVER placeholder & pause & exit /b 1)
if "%VPS_UUID%"=="YOUR_VPS_UUID" (echo ERROR: run option [A] Setup VPS first, then paste VPS_UUID into config.bat & pause & exit /b 1)
if "%VPS_UUID%"=="" (echo ERROR: VPS_UUID empty - run [A] first & pause & exit /b 1)
if "%VPS_PUBLIC_KEY%"=="YOUR_VPS_PUBLIC_KEY" (echo ERROR: VPS_PUBLIC_KEY not set - run [A] first & pause & exit /b 1)
if "%VPS_SHORT_ID%"=="YOUR_VPS_SHORT_ID" (echo ERROR: VPS_SHORT_ID not set - run [A] first & pause & exit /b 1)

:: Auto-derive SNIs if placeholders
set "VPS_SNI_EFFECTIVE=%VPS_SNI%"
if "%VPS_SNI_EFFECTIVE%"=="YOUR_VPS_IP.sslip.io" set "VPS_SNI_EFFECTIVE=%VPS_SERVER%.sslip.io"
if "%VPS_SNI_EFFECTIVE%"=="" set "VPS_SNI_EFFECTIVE=%VPS_SERVER%.sslip.io"

set "RELAY_SNI_EFFECTIVE=%RELAY_SNI%"
if "%RELAY_SNI_EFFECTIVE%"=="YOUR_RELAY_IP.sslip.io" set "RELAY_SNI_EFFECTIVE=%RELAY_SERVER%.sslip.io"
if "%RELAY_SNI_EFFECTIVE%"=="" set "RELAY_SNI_EFFECTIVE=%RELAY_SERVER%.sslip.io"

echo   Relay IP  : %RELAY_SERVER%
echo   Relay SNI : %RELAY_SNI_EFFECTIVE%
echo   Chains to : %VPS_SERVER% (SNI %VPS_SNI_EFFECTIVE%)
echo.
echo   This wipes legacy socat/xray on the relay and installs a fresh
echo   VLESS+REALITY ingress that tunnels to the VPS.
echo.
pause

echo [1/2] Uploading setup script...
scp "%~dp0relay-setup.sh" root@%RELAY_SERVER%:/tmp/relay-setup.sh
if %errorlevel% neq 0 (echo       FAILED & pause & exit /b 1)
echo       OK
echo.

echo [2/2] Running setup on relay...
ssh root@%RELAY_SERVER% "VPS_SERVER=%VPS_SERVER% VPS_UUID=%VPS_UUID% VPS_PUBLIC_KEY=%VPS_PUBLIC_KEY% VPS_SHORT_ID=%VPS_SHORT_ID% VPS_SNI=%VPS_SNI_EFFECTIVE% RELAY_SNI=%RELAY_SNI_EFFECTIVE% bash /tmp/relay-setup.sh"
if %errorlevel% neq 0 (echo       FAILED - see output above & pause & exit /b 1)

echo.
echo ========================================
echo   Next: paste RELAY_UUID / RELAY_PUBLIC_KEY / RELAY_SHORT_ID / RELAY_SNI
echo   shown above into config.bat, then option [C] Setup router.
echo ========================================
echo.
pause
