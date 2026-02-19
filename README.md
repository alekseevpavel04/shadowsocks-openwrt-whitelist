# Shadowsocks VPN Whitelist for OpenWrt

Scripts for managing Shadowsocks VPN on OpenWrt routers.
Only traffic to blocked/throttled domains goes through VPN — everything else is direct (whitelist routing).

## Features

- Whitelist routing — only listed domains go through VPN
- Auto-updating domain lists from GitHub (Re:filter + Zapret)
- Custom domain list (`my-domains.txt`) that is never overwritten on update
- VPN auto-start on router reboot
- DNS interception — all devices on the network use the router's dnsmasq
- UDP blocking for listed domains — forces TCP through VPN (fixes issues with mobile apps)
- Site availability test

## Structure
```
shadowsocks-vpn/
├── vpn-setup.bat          # First-time router setup
├── vpn-start.bat          # Enable VPN and push lists to router
├── vpn-stop.bat           # Disable VPN
├── vpn-update.bat         # Download fresh lists from GitHub
├── vpn-test.bat           # Site availability test
├── config.example.bat     # Config template (copy to config.bat)
├── config.bat             # Your server credentials (not in git)
├── .gitignore
├── README.md
├── templates/
│   └── shadowsocks-init.sh    # Router autostart service script
└── lists/
    ├── community.lst      # [auto] Blocked services list (Re:filter)
    ├── list-general.txt   # [auto] Throttled domains (Zapret)
    ├── list-google.txt    # [auto] Google/YouTube domains (Zapret)
    └── my-domains.txt     # Your custom domains (edit manually)
```

## Requirements

**Router:**
- OpenWrt (tested on GL.iNet Flint 2 / GL-MT6000)
- SSH root access (enabled by default on most OpenWrt routers)
- Internet access for package installation during first setup

**Computer:**
- Windows 10/11 — scripts are `.bat` files
- SSH client and `curl` — built into Windows 10/11, no extra installation needed

> **Linux/macOS:** `.bat` files won't run directly, but all underlying commands (ssh, scp, curl) are standard and can easily be adapted to bash.

Router packages (`shadowsocks-libev-ss-redir`, `ipset`) are installed automatically by `vpn-setup.bat` — no manual installation required.

## Initial Setup

### 1. Fill in your server credentials

Open `config.bat` and set your values:
```bat
set "SS_SERVER=your-server-ip"
set "SS_PORT=443"
set "SS_PASSWORD=your-password"
set "SS_METHOD=chacha20-ietf-poly1305"
```

### 2. Download domain lists
```
vpn-update.bat
```

### 3. Set up the router
```
vpn-setup.bat
```

This script connects to the router via SSH and automatically:
- Installs `shadowsocks-libev-ss-redir` and `ipset` via `opkg`
- Writes the Shadowsocks config to `/etc/shadowsocks-libev/config.json`
- Installs and enables the autostart service at `/etc/init.d/shadowsocks`
- Uploads domain lists to the router

### Note: dnsmasq config directory

Make sure dnsmasq reads configs from `/tmp/dnsmasq.d/`:
```bash
grep "conf-dir" /var/etc/dnsmasq.conf* 2>/dev/null
```

If the output shows a different path — replace `/tmp/dnsmasq.d/` in `templates/shadowsocks-init.sh` with your path, then re-run `vpn-setup.bat`.

## Usage
```
vpn-setup.bat      # First-time router setup
vpn-update.bat     # Download fresh lists (run weekly)
vpn-start.bat      # Enable VPN
vpn-test.bat       # Check site availability
vpn-stop.bat       # Disable VPN
```

VPN starts automatically on router reboot.

## Adding Custom Domains

Open `lists/my-domains.txt` and add domains one per line:
```
x.com
twitter.com
twimg.com
tiktok.com
spotify.com
```

Then run `vpn-start.bat` to apply.

## How It Works

1. `vpn-update.bat` downloads up-to-date domain lists from GitHub
2. `vpn-start.bat` pushes the Shadowsocks config and lists to the router, then configures dnsmasq + ipset + iptables
3. DNS queries from all devices are intercepted and forwarded to the router's dnsmasq
4. When a device resolves a domain from the list, dnsmasq adds its IP to ipset
5. iptables redirects TCP traffic to IPs in ipset through Shadowsocks
6. UDP traffic to listed IPs is dropped, forcing apps to fall back to TCP through VPN
7. All other traffic goes directly

## Recommendations

- **Disable QUIC in Chrome**: `chrome://flags/#enable-quic` → Disabled. YouTube and Google use QUIC (UDP), which does not go through VPN.
- **Disable IPv6** on the router — this VPN only handles IPv4, so IPv6 traffic will bypass it.
- Update lists weekly with `vpn-update.bat`.

## Known Limitations

- Only TCP traffic goes through VPN. UDP is blocked for listed domains, forcing apps to fall back to TCP.
- Discord voice calls (UDP) may not work through the router VPN. Use a device-level VPN app for calls.
- The first request to a new domain may be slow — the ipset is populated on DNS resolution.
- Router firmware updates will wipe all settings — re-run `vpn-setup.bat` afterwards.

## List Sources

- [Re:filter](https://github.com/1andrevich/Re-filter-lists) — up-to-date list of blocked domains and IPs in Russia
- [Zapret](https://github.com/Flowseal/zapret-discord-youtube) — lists of throttled services (YouTube, Discord, Google)

## Compatibility

**Routers:** tested on GL.iNet Flint 2 (GL-MT6000), OpenWrt 21.02. Should work on any OpenWrt router that has `shadowsocks-libev-ss-redir` available in its package repository.

**OS:** scripts are written for Windows (`.bat`). The underlying commands are identical on Linux/macOS — adapting to bash is straightforward.

## Credits

- [bol-van/zapret](https://github.com/bol-van/zapret) — original DPI bypass tool
- [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube) — domain lists
- [1andrevich/Re-filter-lists](https://github.com/1andrevich/Re-filter-lists) — blocked domain lists
- [Admonstrator/glinet-remove-chinalock](https://github.com/Admonstrator/glinet-remove-chinalock) — GL.iNet region unlock

## License

MIT
