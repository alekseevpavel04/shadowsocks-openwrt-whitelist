#!/bin/bash
# Xray VLESS+REALITY server setup
# Run on a fresh Ubuntu VPS: bash vps-setup.sh
set -e

echo "========================================"
echo "  Xray VLESS+REALITY Server Setup"
echo "========================================"
echo ""

# Install xray (skip if already installed)
echo "[1/4] Installing Xray..."
if [ -f /usr/local/bin/xray ]; then
    echo "      Already installed: $(/usr/local/bin/xray version 2>&1 | head -1)"
else
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata
    echo "      OK"
fi
echo ""

# Install geoip.dat (Loyalsoldier — wider RU coverage than v2fly default)
# Required for the routing rule that blocks egress back to Russian IPs.
echo "[2/4] Installing geoip.dat..."
mkdir -p /usr/local/share/xray
if [ ! -s /usr/local/share/xray/geoip.dat ]; then
    curl -fsSL --max-time 60 -o /usr/local/share/xray/geoip.dat \
        https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
fi
echo "      $(ls -lh /usr/local/share/xray/geoip.dat | awk '{print $5}') geoip.dat"
echo ""

# Generate keys and UUID
echo "[3/4] Generating REALITY keys..."
XRAY_BIN=/usr/local/bin/xray
KEYS=$($XRAY_BIN x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep -i "private" | awk '{print $NF}')
PUBLIC_KEY=$(echo "$KEYS"  | grep -i "public"  | awk '{print $NF}')
UUID=$($XRAY_BIN uuid)
SHORT_ID=$(openssl rand -hex 4)

if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ] || [ -z "$SHORT_ID" ]; then
    echo "ERROR: Failed to parse keys. Raw xray x25519 output:"
    echo "$KEYS"
    exit 1
fi
echo "      OK"
echo ""

# Write server config
# routing.rules blocks egress back to Russian / private IPs (defense against
# spy modules in RU apps that would otherwise see VPS IP as source).
# See SECURITY-AUDIT-2026-04.md Fix 1 for the rationale.
echo "[4/4] Writing config and starting Xray..."
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
        "serverNames": ["www.microsoft.com"],
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
      {"type": "field", "outboundTag": "block", "ip": ["geoip:ru", "geoip:private"]}
    ]
  }
}
EOF

systemctl restart xray
systemctl enable xray

# Open port 443 in UFW if active
if ufw status | grep -q "Status: active"; then
    ufw allow 443/tcp
    ufw reload
fi

sleep 2

# Verify
if systemctl is-active --quiet xray; then
    echo "      OK"
    echo ""
    echo "========================================"
    echo "  SUCCESS"
    echo "========================================"
    echo ""
    echo "  Copy these values to config.bat:"
    echo ""
    echo "  XRAY_UUID=$UUID"
    echo "  XRAY_PUBLIC_KEY=$PUBLIC_KEY"
    echo ""
    echo "  (PRIVATE_KEY stays on server only)"
    echo "========================================"
else
    echo ""
    echo "ERROR: Xray failed to start. Logs:"
    journalctl -u xray --no-pager -n 30
    exit 1
fi
