# VPN Whitelist Router (OpenWrt + Xray VLESS+REALITY)

Selective VPN routing on an OpenWrt router. Only traffic to blocked/throttled domains goes through the VPN tunnel — everything else is direct.

**Protocol:** Xray VLESS+REALITY — indistinguishable from regular HTTPS, bypasses DPI (ТСПУ).

## How It Works

1. `vpn-update.bat` downloads fresh domain lists from GitHub
2. `vpn-start.bat` pushes config and lists to the router, configures dnsmasq + ipset + iptables
3. DNS queries from all devices are intercepted by the router's dnsmasq
4. When a device resolves a listed domain, dnsmasq adds its IP to ipset
5. iptables redirects TCP traffic to listed IPs through Xray on port 1080
6. Xray tunnels the traffic via VLESS+REALITY to your VPS
7. UDP to listed IPs is dropped, forcing apps to fall back to TCP

## Requirements

**Router:** OpenWrt (tested on GL.iNet Flint 2 / GL-MT6000, aarch64_cortex-a53), SSH root access

**VPS:** Any Linux VPS outside Russia (Vultr, Hetzner etc.) — Xray is installed automatically by `vpn-server-setup.bat`

**Computer:** Windows 10/11 (SSH + curl built in)

## Setup

### First time

```
1. Deploy VPS: Vultr → Cloud Compute (Shared CPU), Ubuntu 24.04, Amsterdam/Frankfurt, $6/mo
2. Copy config.example.bat → config.bat, set XRAY_SERVER to the VPS IP
3. vpn-server-setup.bat   — installs Xray on VPS, prints UUID + PUBLIC_KEY
4. Fill UUID + PUBLIC_KEY into config.bat
5. vpn-addkey-server.bat  — setup SSH key for VPS (no more password prompts)
6. vpn-addkey.bat         — setup SSH key for router
7. vpn-update.bat         — download domain lists
8. vpn-setup.bat          — install Xray on router, upload config
9. vpn-start.bat          — enable VPN
```

> **Note:** On Ubuntu VPS, UFW is enabled by default and blocks all ports except 22.
> `vpn-server-setup.bat` opens port 443 automatically. If you set up the server manually,
> run: `ufw allow 443/tcp && ufw reload`

### Daily use

```
vpn-start.bat     — enable VPN
vpn-stop.bat      — disable VPN
vpn-update.bat    — refresh domain lists (weekly)
vpn-test.bat      — check site availability
```

## Adding Custom Domains

Edit `lists/my-domains.txt`, one domain per line:
```
x.com
twitter.com
spotify.com
```
Then run `vpn-start.bat` to apply.

## Structure

```
config.bat / config.example.bat   — VPS credentials (config.bat not in git)
server-setup.sh                   — Xray install script for VPS (run via vpn-server-setup.bat)
vpn-server-setup.bat              — one-time VPS setup
vpn-setup.bat                     — one-time router setup
vpn-start.bat                     — enable VPN
vpn-stop.bat                      — disable VPN
vpn-update.bat                    — refresh lists
vpn-test.bat                      — test sites
vpn-addkey.bat                    — setup SSH key for router (no more password prompts)
vpn-addkey-server.bat             — setup SSH key for VPS
templates/xray-router.json        — Xray config template for router
templates/shadowsocks-init.sh     — router autostart service
lists/                            — domain lists
```

## Recommendations

- **Disable QUIC in Chrome:** `chrome://flags/#enable-quic` → Disabled (YouTube uses QUIC/UDP which bypasses the VPN)
- **Disable IPv6** on the router — only IPv4 is handled
- Update lists weekly with `vpn-update.bat`
- Router firmware updates wipe settings — re-run `vpn-setup.bat` afterwards

## Known Limitations

- Only TCP traffic goes through VPN. UDP is dropped for listed domains (forces TCP fallback).
- Discord voice calls (UDP) won't work through router VPN — use a device-level VPN app for calls.
- First request to a new domain may be slow — ipset is populated on DNS resolution.

## Detection Risks

### What your ISP cannot see
- That this is a VPN. REALITY performs a real TLS 1.3 handshake (SNI: `www.microsoft.com`, fingerprint: Chrome). The traffic is cryptographically indistinguishable from regular HTTPS browsing.
- Which sites you visit through the tunnel.
- Whether you are bypassing blocks — there are no grounds for automated blocking (unlike the IP ranges of known commercial VPN services).

### What your ISP can see
- That your device connects to a foreign IP (your VPS) on port 443.
- The VPS IP belongs to a hosting provider (Vultr/Hetzner), not a Microsoft CDN. A sophisticated DPI could theoretically flag the SNI/IP mismatch — but in practice, random personal VPS IPs are not specifically targeted.
- **Your traffic physically crosses the border** — this is counted as cross-border traffic regardless of protocol obfuscation.

### Cross-border traffic billing (proposed legislation)
Russian ISPs may eventually be required to pay the state per GB of outgoing cross-border traffic and pass the costs to users. If this happens:
- Traffic to your VPS abroad counts as cross-border — even though the ISP cannot identify it as VPN traffic.
- With selective routing (only blocked domains go through the tunnel), the total affected volume is minimal — most traffic stays domestic.

### Connecting directly from a mobile device (without the router)
The same analysis applies to mobile carriers. When using a VLESS client app (v2rayNG, Shadowrocket) directly on a phone, the carrier sees connections to a foreign IP. Using selective routing rules in the app reduces the cross-border volume.

## List Sources

- [Re:filter](https://github.com/1andrevich/Re-filter-lists) — blocked domains/IPs in Russia
- [Zapret](https://github.com/Flowseal/zapret-discord-youtube) — throttled services (YouTube, Discord, Google)

## License

MIT
