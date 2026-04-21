@echo off

echo ========================================
echo   VPN - UPDATE LISTS
echo ========================================
echo.

set "LISTS_DIR=%~dp0..\lists"
set "OK=1"

echo [1/3] Re:filter - community.lst ...
curl -sfL -o "%LISTS_DIR%\community.lst.tmp" "https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/community.lst"
if %errorlevel% neq 0 (echo       FAILED ^(keeping old file^) & del "%LISTS_DIR%\community.lst.tmp" 2>nul & set "OK=0") else (move /y "%LISTS_DIR%\community.lst.tmp" "%LISTS_DIR%\community.lst" >nul & echo       OK)

echo [2/3] Zapret - list-general.txt ...
curl -sfL -o "%LISTS_DIR%\list-general.txt.tmp" "https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/lists/list-general.txt"
if %errorlevel% neq 0 (echo       FAILED ^(keeping old file^) & del "%LISTS_DIR%\list-general.txt.tmp" 2>nul & set "OK=0") else (move /y "%LISTS_DIR%\list-general.txt.tmp" "%LISTS_DIR%\list-general.txt" >nul & echo       OK)

echo [3/3] Zapret - list-google.txt ...
curl -sfL -o "%LISTS_DIR%\list-google.txt.tmp" "https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/lists/list-google.txt"
if %errorlevel% neq 0 (echo       FAILED ^(keeping old file^) & del "%LISTS_DIR%\list-google.txt.tmp" 2>nul & set "OK=0") else (move /y "%LISTS_DIR%\list-google.txt.tmp" "%LISTS_DIR%\list-google.txt" >nul & echo       OK)

echo.
if "%OK%"=="1" (
    echo ========================================
    echo   All lists updated!
    echo   Run option [1] Start VPN to apply.
    echo ========================================
) else (
    echo ========================================
    echo   Some lists failed to download.
    echo   Check your internet connection.
    echo ========================================
)
echo.
pause
