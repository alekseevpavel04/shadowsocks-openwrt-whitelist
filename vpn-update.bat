@echo off

echo ========================================
echo   VPN - UPDATE LISTS
echo ========================================
echo.

set "LISTS_DIR=%~dp0lists"
set "OK=1"

echo [1/5] Re:filter - domains_all.lst ...
curl -sL -o "%LISTS_DIR%\domains_all.lst" "https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/domains_all.lst"
if %errorlevel% neq 0 (echo       FAILED & set "OK=0") else (echo       OK)

echo [2/5] Re:filter - community.lst ...
curl -sL -o "%LISTS_DIR%\community.lst" "https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/community.lst"
if %errorlevel% neq 0 (echo       FAILED & set "OK=0") else (echo       OK)

echo [3/5] Zapret - list-general.txt ...
curl -sL -o "%LISTS_DIR%\list-general.txt" "https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/lists/list-general.txt"
if %errorlevel% neq 0 (echo       FAILED & set "OK=0") else (echo       OK)

echo [4/5] Zapret - list-google.txt ...
curl -sL -o "%LISTS_DIR%\list-google.txt" "https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/lists/list-google.txt"
if %errorlevel% neq 0 (echo       FAILED & set "OK=0") else (echo       OK)

echo [5/5] Checking my-domains.txt ...
if exist "%LISTS_DIR%\my-domains.txt" (
    echo       Found
) else (
    echo # Your custom domains, one per line> "%LISTS_DIR%\my-domains.txt"
    echo # Lines starting with # are ignored>> "%LISTS_DIR%\my-domains.txt"
    echo       Created template
)

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
