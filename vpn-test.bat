@echo off

echo ========================================
echo   VPN - SPEED TEST
echo ========================================
echo.

echo Your IP:
curl -s --max-time 5 ifconfig.me/ip
echo.
echo.

echo --- Russian sites (baseline, no VPN) ---
for %%s in (vk.com ya.ru mail.ru dzen.ru) do (
    curl -so /dev/null -w "  %%s: %%{http_code} | %%{time_total}s" --max-time 10 "https://%%s"
    echo.
)

echo.
echo --- Blocked/throttled sites (via VPN) ---
for %%s in (youtube.com discord.com instagram.com x.com tiktok.com facebook.com twitter.com spotify.com medium.com) do (
    curl -so /dev/null -w "  %%s: %%{http_code} | %%{time_total}s" --max-time 10 "https://%%s"
    echo.
)

echo.
echo --- Other popular sites ---
for %%s in (google.com web.telegram.org github.com reddit.com twitch.tv linkedin.com) do (
    curl -so /dev/null -w "  %%s: %%{http_code} | %%{time_total}s" --max-time 10 "https://%%s"
    echo.
)

echo.
echo ========================================
echo   200/301/302 = OK, 000 = blocked/timeout
echo ========================================
echo.
pause