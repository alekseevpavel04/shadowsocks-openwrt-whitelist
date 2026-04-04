@echo off
echo ========================================
echo   VPN - SETUP SSH KEY FOR RELAY (one-time)
echo ========================================
echo.
echo   After this you will never be asked for
echo   the relay server password again.
echo.
echo   You will be asked for the password ONCE now.
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

set "KEYFILE=%USERPROFILE%\.ssh\id_ed25519"

if not exist "%USERPROFILE%\.ssh" mkdir "%USERPROFILE%\.ssh"

if not exist "%KEYFILE%" (
    echo [1/2] Generating SSH key...
    ssh-keygen -t ed25519 -N "" -f "%KEYFILE%"
    echo       OK
) else (
    echo [1/2] SSH key already exists, skipping.
)
echo.

echo [2/2] Copying key to relay %RELAY_SERVER% (enter password when prompted)...
type "%KEYFILE%.pub" | ssh root@%RELAY_SERVER% "mkdir -p /root/.ssh && cat >> /root/.ssh/authorized_keys && sort -u /root/.ssh/authorized_keys -o /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys && chmod 700 /root/.ssh && echo 'Key added.'"
if %errorlevel% neq 0 (
    echo       FAILED
    pause
    exit /b 1
)
echo       OK
echo.

echo [Test] Checking passwordless login...
ssh -o BatchMode=yes -i "%KEYFILE%" root@%RELAY_SERVER% "echo OK"
if %errorlevel% neq 0 (
    echo       WARNING: key may not have been accepted. Try running again.
) else (
    echo       Works! No more password prompts.
)
echo.

echo ========================================
echo   Done.
echo ========================================
echo.
pause
