# VPN Manager — menu display
# Called by vpn.bat; displays colored menu then exits.
# Input is read by the calling batch script.

$line = [string]([char]0x2500) * 48
$Host.UI.RawUI.WindowTitle = "VPN Manager"
Clear-Host

function Section([string]$title) {
    Write-Host
    Write-Host "  $title" -ForegroundColor Yellow
    Write-Host "  $line"  -ForegroundColor DarkGray
}

function Item([string]$key, [string]$name, [string]$desc) {
    Write-Host -NoNewline "  "
    Write-Host -NoNewline "[$key]" -ForegroundColor Cyan
    Write-Host -NoNewline "  $($name.PadRight(14))" -ForegroundColor White
    Write-Host $desc -ForegroundColor DarkGray
}

function Step([string]$key, [string]$n, [string]$name, [string]$desc) {
    Write-Host -NoNewline "  "
    Write-Host -NoNewline "[$key]" -ForegroundColor Cyan
    Write-Host -NoNewline "  "
    Write-Host -NoNewline "$n." -ForegroundColor DarkYellow
    Write-Host -NoNewline "  $($name.PadRight(8))" -ForegroundColor White
    Write-Host $desc -ForegroundColor DarkGray
}

Write-Host
Write-Host "  VPN MANAGER" -ForegroundColor Cyan
Write-Host "  $line"       -ForegroundColor DarkGray

Section "DAILY USE"
Item "1" "Start VPN"    "upload config + apply routing"
Item "2" "Stop VPN"     "remove routing (xray stays installed)"
Item "3" "Update lists" "download blocked domains from GitHub"

Section "DIAGNOSTICS"
Item "4" "Test sites"   "HTTP status + response time per site"
Item "5" "Full trace"   "check relay / router / exit IP"
Item "E" "Speed test"   "per-hop bandwidth + latency"

Section "MOBILE"
Item "6" "Phone config" "VLESS URL for Shadowrocket / v2rayNG"

Section "SSH KEYS  (run once per machine)"
Write-Host -NoNewline "  "
Write-Host -NoNewline "[7]" -ForegroundColor Cyan
Write-Host -NoNewline "  Router      " -ForegroundColor White
Write-Host -NoNewline "[8]" -ForegroundColor Cyan
Write-Host -NoNewline "  Amsterdam VPS   " -ForegroundColor White
Write-Host -NoNewline "[9]" -ForegroundColor Cyan
Write-Host   "  Timeweb relay" -ForegroundColor White

Section "INSTALL & CONFIGURE  (follow this order)"
Step "A" "1" "VPS"    "install Xray; outputs UUID + PUBLIC_KEY"
Step "B" "2" "Relay"  "forward port 443 to Amsterdam via socat"
Step "C" "3" "Router" "install xray binary + autostart service"
Step "D" "4" "UFW"    "relay firewall: allow only 22 + 443"

Write-Host
Write-Host "  $line" -ForegroundColor DarkGray
Write-Host -NoNewline "  "
Write-Host -NoNewline "[Q]" -ForegroundColor Cyan
Write-Host "  Quit" -ForegroundColor DarkGray
Write-Host
