# VPN Whitelist Router (OpenWrt + Xray VLESS+REALITY)

Selective VPN routing on an OpenWrt router. Only traffic to blocked/throttled domains goes through the VPN tunnel — everything else is direct.

**Protocol:** Xray VLESS+REALITY — indistinguishable from regular HTTPS, bypasses DPI (ТСПУ).

**Entry point:** run `vpn.bat` — interactive menu for all operations.

## How It Works

1. `[3] Update lists` downloads fresh domain lists from GitHub
2. `[1] Start VPN` pushes config and lists to the router, configures dnsmasq + ipset + iptables
3. DNS queries from all devices are intercepted by the router's dnsmasq
4. When a device resolves a listed domain, dnsmasq adds its IP to ipset
5. iptables redirects TCP traffic to listed IPs through Xray on port 1080
6. Xray tunnels the traffic via VLESS+REALITY → RU relay (socat) → Amsterdam VPS
7. UDP to listed IPs is dropped, forcing apps to fall back to TCP

## Requirements

**Router:** OpenWrt (tested on GL.iNet Flint 2 / GL-MT6000, aarch64_cortex-a53), SSH root access

**VPS:** Any Linux VPS outside Russia (Vultr, Hetzner etc.) — Xray is installed automatically by `[A] Setup VPS`

**Relay (optional):** Russian VPS with socat — hides cross-border traffic from ISP

**Computer:** Windows 10/11 (SSH + curl built in)

## Setup

### First time (in order)

```
1. Deploy VPS: Vultr → Cloud Compute (Shared CPU), Ubuntu 24.04, Amsterdam, ~$6/mo
2. Deploy relay: Timeweb → Ubuntu 24.04, any Russian datacenter (optional but recommended)
3. Copy config.example.bat → config.bat, set VPS_SERVER and RELAY_SERVER
4. vpn.bat → [A] Setup VPS     — installs Xray on VPS, prints VPS_UUID + VPS_PUBLIC_KEY + VPS_SHORT_ID
5. Fill VPS_* values into config.bat
6. vpn.bat → [B] Setup relay   — installs Xray chain on relay, prints RELAY_UUID + RELAY_PUBLIC_KEY + RELAY_SHORT_ID (fill into config.bat)
7. vpn.bat → [C] Setup router  — installs Xray on router, uploads config
8. vpn.bat → [D] Enable UFW    — locks down relay firewall (22 + 443 only)
9. vpn.bat → [7] SSH key: router   — one-time, no more password prompts
10. vpn.bat → [8] SSH key: VPS     — one-time
11. vpn.bat → [9] SSH key: relay   — one-time
12. vpn.bat → [3] Update lists — download domain lists
13. vpn.bat → [1] Start VPN    — enable VPN
```

> **Note:** On Ubuntu VPS, UFW is enabled by default and blocks all ports except 22.
> `[A] Setup VPS` opens port 443 automatically. If you set up the server manually,
> run: `ufw allow 443/tcp && ufw reload`

### Daily use

```
vpn.bat → [1] Start VPN      — enable VPN
vpn.bat → [2] Stop VPN       — disable VPN
vpn.bat → [3] Update lists   — refresh domain lists (weekly)
vpn.bat → [4] Test sites     — check site availability
vpn.bat → [5] Trace route    — diagnose each hop: PC → relay → Amsterdam → internet
```

## Adding Custom Domains

Edit `lists/my-domains.txt`, one domain per line:
```
x.com
twitter.com
spotify.com
```
Then run `[1] Start VPN` to apply.

## Structure

```
vpn.bat                           — entry point: interactive menu
config.bat / config.example.bat   — VPS credentials (config.bat not in git)

scripts/
  menu.ps1                        — colored menu display (PowerShell)
  vpn-start.bat                   — [1] enable VPN
  vpn-stop.bat                    — [2] disable VPN
  vpn-update.bat                  — [3] refresh domain lists
  vpn-test.bat                    — [4] test site availability
  vpn-trace.bat                   — [5] trace each hop
  shadowrocket-config.bat         — [6] VLESS URL for mobile (Shadowrocket/v2rayNG)
  vpn-addkey.bat                  — [7] SSH key for router
  vpn-addkey-vps.bat              — [8] SSH key for VPS
  vpn-addkey-relay.bat            — [9] SSH key for relay
  vpn-setup-vps.bat               — [A] one-time VPS setup
  vpn-setup-relay.bat             — [B] one-time relay setup
  vpn-setup.bat                   — [C] one-time router setup
  vpn-relay-ufw.bat               — [D] enable UFW on relay
  vps-setup.sh                    — Xray install script for VPS
  relay-setup.sh                  — socat relay install script

templates/xray-router.json        — Xray config template for router
templates/vpn-init.sh             — router autostart service (/etc/init.d/shadowsocks)
lists/                            — domain lists
```

## Recommendations

- **Disable QUIC in Chrome:** `chrome://flags/#enable-quic` → Disabled (YouTube uses QUIC/UDP which bypasses the VPN)
- **Disable IPv6** on the router — only IPv4 is handled
- Update lists weekly with `[3] Update lists`
- Router firmware updates wipe settings — re-run `[C] Setup router` afterwards

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
- That your device connects to a Russian IP (relay server) on port 443.
- With relay: cross-border traffic is hidden — ISP sees only domestic connections.
- Without relay: ISP sees connection to a foreign hosting IP (Vultr/Hetzner).

### Cross-border traffic billing (proposed legislation)
Russian ISPs may eventually be required to pay the state per GB of outgoing cross-border traffic and pass the costs to users. If this happens:
- The relay eliminates cross-border traffic at the user level entirely.
- Without relay: traffic to the VPS abroad counts, but with selective routing the volume is minimal.

### Connecting directly from a mobile device (without the router)

> **Security warning (April 2026):** all popular Android VLESS clients
> (`v2rayNG`, `NekoBox`, `Hiddify`, `Happ`, `v2RayTun`, `V2BOX`, `Exclave`,
> `Npv Tunnel`) ship with an **unauthenticated localhost SOCKS5 proxy**.
> Any other app on the device — including spy modules embedded in Russian
> applications (Yandex, MAX, Sber, Gosuslugi, Wildberries, Ozon) — can
> connect to that proxy, bypass per-app split tunneling and Knox/Shelter
> private spaces, and learn the VPN exit IP. Once leaked, the IP gets
> blocked by RKN. **As of April 2026 there is no patched Android client.**
>
> **Mitigation:** prefer connecting through this router's wifi instead of
> running a VLESS client directly on the phone. The router uses transparent
> TPROXY (not SOCKS5) and is not affected by the same attack. If you must
> use a mobile client, iOS Shadowrocket is not on the public list of
> vulnerable clients (but it is closed source — no guarantees). Do not
> install any VLESS client on a phone that also has Russian state-adjacent
> apps installed. Source: `runetfreedom` on Habr, April 2026.

Use `[6] Mobile config` to get the VLESS URL for Shadowrocket (iOS).
The same REALITY obfuscation applies — carrier sees HTTPS to `www.microsoft.com`.

## List Sources

- [Re:filter](https://github.com/1andrevich/Re-filter-lists) — blocked domains/IPs in Russia
- [Zapret](https://github.com/Flowseal/zapret-discord-youtube) — throttled services (YouTube, Discord, Google)

## License

MIT
