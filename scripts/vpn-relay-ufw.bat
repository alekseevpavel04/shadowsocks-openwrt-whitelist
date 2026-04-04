@echo off
echo ========================================
echo   RELAY - Enable UFW Firewall (one-time)
echo   Allow: 22 (SSH) + 443 (VPN relay)
echo   Block: everything else
echo ========================================
echo.

if not exist "%~dp0..\config.bat" (
    echo ERROR: config.bat not found.
    pause & exit /b 1
)
call "%~dp0..\config.bat"

if "%RELAY_SERVER%"=="" (echo ERROR: RELAY_SERVER not set in config.bat & pause & exit /b 1)
if "%RELAY_SERVER%"=="YOUR_RELAY_IP" (echo ERROR: RELAY_SERVER not set in config.bat & pause & exit /b 1)

echo   Relay: %RELAY_SERVER%
echo.
echo   This will activate UFW and allow ONLY ports 22 and 443.
echo   SSH access will be preserved.
echo.
pause

echo Configuring UFW on relay...
ssh root@%RELAY_SERVER% "apt-get install -y -qq ufw 2>/dev/null; ufw default deny incoming; ufw default allow outgoing; ufw allow 22/tcp; ufw allow 443/tcp; ufw --force enable; ufw status"

if %errorlevel% neq 0 (
    echo.
    echo FAILED - see errors above
    pause & exit /b 1
)

echo.
echo ========================================
echo   Done. UFW is active.
echo   Allowed: 22/tcp (SSH) + 443/tcp (VPN)
echo   All other inbound ports: BLOCKED
echo ========================================
echo.
pause
