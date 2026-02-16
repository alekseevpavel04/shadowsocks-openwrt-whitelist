@echo off

echo ========================================
echo   VPN - UPDATE LISTS
echo ========================================
echo.

set "LISTS_DIR=%~dp0lists"
set "OK=1"

echo [1/3] Re:filter - community.lst ...
curl -sL -o "%LISTS_DIR%\community.lst" "https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/community.lst"
if %errorlevel% neq 0 (echo       FAILED & set "OK=0") else (echo       OK)

echo [2/3] Zapret - list-general.txt ...
curl -sL -o "%LISTS_DIR%\list-general.txt" "https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/lists/list-general.txt"
if %errorlevel% neq 0 (echo       FAILED & set "OK=0") else (echo       OK)

echo [3/3] Zapret - list-google.txt ...
curl -sL -o "%LISTS_DIR%\list-google.txt" "https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/lists/list-google.txt"
if %errorlevel% neq 0 (echo       FAILED & set "OK=0") else (echo       OK)

echo.
if "%OK%"=="1" (
    echo ========================================
    echo   All lists updated!
    echo   Run vpn-start.bat to apply.
    echo ========================================
) else (
    echo ========================================
    echo   Some lists failed to download.
    echo   Check your internet connection.
    echo ========================================
)
echo.
pause