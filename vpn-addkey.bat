@echo off
echo ========================================
echo   VPN - SETUP SSH KEY (one-time)
echo ========================================
echo.
echo   After this you will never be asked for
echo   the router password again.
echo.
echo   You will be asked for the password ONCE now.
echo.

set "ROUTER=192.168.8.1"
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

echo [2/2] Copying key to router (enter password when prompted)...
type "%KEYFILE%.pub" | ssh root@%ROUTER% "mkdir -p /root/.ssh && (grep -E '^(ssh-|ecdsa-|sk-)' /root/.ssh/authorized_keys 2>/dev/null; grep -E '^(ssh-|ecdsa-|sk-)' /etc/dropbear/authorized_keys 2>/dev/null; cat) | tr -d '\r' | sort -u > /tmp/auth_new && cp /tmp/auth_new /root/.ssh/authorized_keys && mkdir -p /etc/dropbear && cp /tmp/auth_new /etc/dropbear/authorized_keys && chmod 600 /root/.ssh/authorized_keys /etc/dropbear/authorized_keys && chmod 700 /root/.ssh && echo 'Key added.'"
if %errorlevel% neq 0 (
    echo       FAILED
    pause
    exit /b 1
)
echo       OK
echo.

echo [Test] Checking passwordless login...
ssh -o BatchMode=yes -i "%KEYFILE%" root@%ROUTER% "echo OK"
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
