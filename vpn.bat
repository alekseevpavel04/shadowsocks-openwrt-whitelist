@echo off
setlocal EnableDelayedExpansion
set "SCRIPTS=%~dp0scripts"

:menu
powershell -NoProfile -File "%SCRIPTS%\menu.ps1"
set /p "CHOICE=   > "
echo.

if /i "!CHOICE!"=="1" call "%SCRIPTS%\vpn-start.bat"
if /i "!CHOICE!"=="2" call "%SCRIPTS%\vpn-stop.bat"
if /i "!CHOICE!"=="3" call "%SCRIPTS%\vpn-update.bat"
if /i "!CHOICE!"=="4" call "%SCRIPTS%\vpn-test.bat"
if /i "!CHOICE!"=="5" call "%SCRIPTS%\vpn-trace.bat"
if /i "!CHOICE!"=="6" call "%SCRIPTS%\shadowrocket-config.bat"
if /i "!CHOICE!"=="7" call "%SCRIPTS%\vpn-addkey.bat"
if /i "!CHOICE!"=="8" call "%SCRIPTS%\vpn-addkey-vps.bat"
if /i "!CHOICE!"=="9" call "%SCRIPTS%\vpn-addkey-relay.bat"
if /i "!CHOICE!"=="A" call "%SCRIPTS%\vpn-setup-vps.bat"
if /i "!CHOICE!"=="B" call "%SCRIPTS%\vpn-setup-relay.bat"
if /i "!CHOICE!"=="C" call "%SCRIPTS%\vpn-setup.bat"
if /i "!CHOICE!"=="D" call "%SCRIPTS%\vpn-relay-ufw.bat"
if /i "!CHOICE!"=="Q" exit /b

goto :menu
