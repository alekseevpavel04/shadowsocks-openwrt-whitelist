#!/bin/bash
# Relay Xray setup: two-hop chain.
#   - Inbound  :443 VLESS+TCP+VISION+REALITY (with its own domain/keys)
#   - Outbound VLESS+TCP+VISION+REALITY -> VPS_SERVER:443 (with VPS domain/keys)
# Each hop is an independent REALITY handshake — each passes SNI->IP check.
# Run via vpn-setup-relay.bat, which passes VPS_* + RELAY_SNI as env.
set -e

echo "========================================"
echo "  Relay Xray setup (ingress, SPB)"
echo "========================================"
echo ""

: "${VPS_SERVER:?VPS_SERVER env var not set}"
: "${VPS_UUID:?VPS_UUID env var not set}"
: "${VPS_PUBLIC_KEY:?VPS_PUBLIC_KEY env var not set}"
: "${VPS_SHORT_ID:?VPS_SHORT_ID env var not set}"
: "${VPS_SNI:?VPS_SNI env var not set}"
: "${RELAY_SNI:?RELAY_SNI env var not set}"

# [1/6] BBR.
echo "[1/6] Enabling BBR..."
modprobe tcp_bbr 2>/dev/null || true
sysctl -w net.core.default_qdisc=fq >/dev/null
sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null
if ! grep -q "tcp_congestion_control=bbr" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
fi
echo "      $(sysctl -n net.ipv4.tcp_congestion_control)"
echo ""

# [2/6] Wipe legacy socat-based relay if present.
echo "[2/6] Wiping any legacy relay (socat/old xray)..."
systemctl stop vpn-relay 2>/dev/null || true
systemctl disable vpn-relay 2>/dev/null || true
rm -f /etc/systemd/system/vpn-relay.service
pkill -9 socat 2>/dev/null || true
systemctl daemon-reload
echo "      OK"
echo ""

# [3/6] Install Xray.
echo "[3/6] Installing Xray..."
if [ -f /usr/local/bin/xray ]; then
    echo "      already present: $(/usr/local/bin/xray version 2>&1 | head -1)"
else
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata
fi
echo ""

# [4/6] Generate own REALITY keys + UUID + shortId.
echo "[4/6] Generating REALITY keys for relay..."
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

# [5/6] Write chain config.
echo "[5/6] Writing config and starting Xray..."
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
        "serverNames": ["$RELAY_SNI"],
        "privateKey": "$PRIVATE_KEY",
        "shortIds": ["$SHORT_ID"]
      }
    }
  }],
  "outbounds": [{
    "tag": "vps-chain",
    "protocol": "vless",
    "settings": {"vnext": [{
      "address": "$VPS_SERVER",
      "port": 443,
      "users": [{"id": "$VPS_UUID", "flow": "xtls-rprx-vision", "encryption": "none"}]
    }]},
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "fingerprint": "chrome",
        "serverName": "$VPS_SNI",
        "publicKey": "$VPS_PUBLIC_KEY",
        "shortId": "$VPS_SHORT_ID"
      }
    }
  }]
}
EOF

systemctl restart xray
systemctl enable xray >/dev/null 2>&1

# [6/6] UFW.
echo "[6/6] UFW: allow 22+443..."
apt-get install -y -qq ufw >/dev/null 2>&1 || true
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw allow 22/tcp >/dev/null
ufw allow 443/tcp >/dev/null
ufw --force enable >/dev/null
echo "      OK"
echo ""

sleep 2
if ! systemctl is-active --quiet xray; then
    echo "ERROR: Xray failed to start."
    journalctl -u xray --no-pager -n 30
    exit 1
fi

# Smoke-test relay->VPS chain.
if timeout 3 bash -c ">/dev/tcp/$VPS_SERVER/443" 2>/dev/null; then
    CHAIN_TEST="OK"
else
    CHAIN_TEST="UNREACHABLE (check VPS firewall)"
fi

echo "========================================"
echo "  RELAY SUCCESS"
echo "========================================"
echo ""
echo "  Relay->VPS TCP probe: $CHAIN_TEST"
echo ""
echo "  Paste into config.bat:"
echo ""
echo "  RELAY_UUID=$UUID"
echo "  RELAY_PUBLIC_KEY=$PUBLIC_KEY"
echo "  RELAY_SHORT_ID=$SHORT_ID"
echo "  RELAY_SNI=$RELAY_SNI"
echo ""
echo "========================================"
