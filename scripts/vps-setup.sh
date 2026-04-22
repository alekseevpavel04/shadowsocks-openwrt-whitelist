#!/bin/bash
# VPS Xray setup: VLESS+TCP+VISION+REALITY inbound on :443.
# Egress node — no outbound chain, freedom to internet.
# Run via vpn-setup-vps.bat, which passes VPS_SNI as env.
set -e

echo "========================================"
echo "  VPS Xray setup (egress, Amsterdam)"
echo "========================================"
echo ""

if [ -z "$VPS_SNI" ]; then
    echo "ERROR: VPS_SNI env var not set (expected from vpn-setup-vps.bat)"
    exit 1
fi

# [1/5] BBR. Default Ubuntu uses cubic; on long-haul with any loss BBR is ~5x faster.
echo "[1/5] Enabling BBR..."
modprobe tcp_bbr 2>/dev/null || true
sysctl -w net.core.default_qdisc=fq >/dev/null
sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null
if ! grep -q "tcp_congestion_control=bbr" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
fi
echo "      $(sysctl -n net.ipv4.tcp_congestion_control)"
echo ""

# [2/5] Xray install.
echo "[2/5] Installing Xray..."
if [ -f /usr/local/bin/xray ]; then
    echo "      already present: $(/usr/local/bin/xray version 2>&1 | head -1)"
else
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata
fi
echo ""

# [3/5] geoip (for blackhole of private IPs).
echo "[3/5] Installing geoip.dat..."
mkdir -p /usr/local/share/xray
if [ ! -s /usr/local/share/xray/geoip.dat ]; then
    curl -fsSL --max-time 60 -o /usr/local/share/xray/geoip.dat \
        https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
fi
echo "      $(ls -lh /usr/local/share/xray/geoip.dat | awk '{print $5}')"
echo ""

# [4/5] Generate keys + UUID + shortId.
echo "[4/5] Generating REALITY keys..."
KEYS=$(/usr/local/bin/xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep -i "private" | awk '{print $NF}')
PUBLIC_KEY=$(echo  "$KEYS" | grep -i "public"  | awk '{print $NF}')
UUID=$(/usr/local/bin/xray uuid)
SHORT_ID=$(openssl rand -hex 4)
if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ] || [ -z "$SHORT_ID" ] || [ -z "$UUID" ]; then
    echo "ERROR: key generation failed."
    exit 1
fi
echo "      OK"
echo ""

# [5/5] Config + start.
# No geoip:ru blackhole — Loyalsoldier base classifies Akamai edge as RU
# and breaks TikTok/Adobe (Problem 10 in CLAUDE.md).
echo "[5/5] Writing config and starting Xray..."
mkdir -p /usr/local/etc/xray
cat > /usr/local/etc/xray/config.json << EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [{
    "listen": "0.0.0.0",
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [{"id": "$UUID", "flow": "xtls-rprx-vision"}],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "dest": "www.microsoft.com:443",
        "serverNames": ["$VPS_SNI"],
        "privateKey": "$PRIVATE_KEY",
        "shortIds": ["$SHORT_ID"]
      }
    }
  }],
  "outbounds": [
    {"protocol": "freedom", "tag": "direct"},
    {"protocol": "blackhole", "tag": "block"}
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {"type": "field", "outboundTag": "block", "ip": ["geoip:private"]}
    ]
  }
}
EOF

systemctl restart xray
systemctl enable xray >/dev/null 2>&1

if ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow 443/tcp >/dev/null
    ufw reload >/dev/null
fi

sleep 2
if ! systemctl is-active --quiet xray; then
    echo "ERROR: Xray failed to start."
    journalctl -u xray --no-pager -n 30
    exit 1
fi

echo "      OK"
echo ""
echo "========================================"
echo "  VPS SUCCESS"
echo "========================================"
echo ""
echo "  Paste into config.bat:"
echo ""
echo "  VPS_UUID=$UUID"
echo "  VPS_PUBLIC_KEY=$PUBLIC_KEY"
echo "  VPS_SHORT_ID=$SHORT_ID"
echo "  VPS_SNI=$VPS_SNI"
echo ""
echo "  (private key stays on VPS only)"
echo "========================================"
