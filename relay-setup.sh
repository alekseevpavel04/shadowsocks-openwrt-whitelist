#!/bin/bash
# Socat relay: forward local :443 to Amsterdam VPS
# Run on the Russian relay VPS via vpn-setup-relay.bat
set -e

TARGET="$XRAY_SERVER"
if [ -z "$TARGET" ]; then
    echo "ERROR: XRAY_SERVER environment variable not set"
    exit 1
fi

echo "========================================"
echo "  Relay Setup"
echo "  :443 -> $TARGET:443"
echo "========================================"
echo ""

echo "[1/3] Installing socat..."
apt-get update -qq
apt-get install -y -qq socat
echo "      OK"
echo ""

echo "[2/3] Creating systemd service..."
cat > /etc/systemd/system/vpn-relay.service << EOF
[Unit]
Description=VPN relay -- :443 to $TARGET:443
After=network.target

[Service]
ExecStart=/usr/bin/socat TCP4-LISTEN:443,fork,reuseaddr TCP4:$TARGET:443
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vpn-relay
systemctl restart vpn-relay
echo "      OK"
echo ""

echo "[3/3] Configuring UFW firewall..."
apt-get install -y -qq ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 443/tcp
ufw --force enable
echo "      OK (22+443 allowed, all else blocked)"
echo ""

sleep 2

if systemctl is-active --quiet vpn-relay; then
    RELAY_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    echo "========================================"
    echo "  SUCCESS"
    echo "========================================"
    echo ""
    echo "  Relay IP : $RELAY_IP"
    echo "  Forwards : $RELAY_IP:443 -> $TARGET:443"
    echo ""
    echo "  Make sure config.bat has:"
    echo "  RELAY_SERVER=$RELAY_IP"
    echo "========================================"
else
    echo ""
    echo "ERROR: relay failed to start."
    journalctl -u vpn-relay --no-pager -n 20
    exit 1
fi
