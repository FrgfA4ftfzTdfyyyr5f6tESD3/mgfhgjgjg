#!/bin/bash
# ============================================================
# entrypoint.sh — VLESS-WebSocket + Argo Tunnel Starter
# ============================================================
# This script:
#   1. Generates/validates UUID (Linux-native, NO Node.js)
#   2. Creates Xray config (VLESS over WebSocket)
#   3. Starts Xray-core on INTERNAL_PORT
#   4. Starts cloudflared Argo Tunnel
#   5. Waits for tunnel URL, filters api.trycloudflare.com
#   6. Prints the complete VLESS connection link
# ============================================================

set -e

# ─────────────────────────────────────────────
# 1. UUID: generate Linux-natively or validate
# ─────────────────────────────────────────────
generate_uuid() {
    if [ -r /proc/sys/kernel/random/uuid ]; then
        cat /proc/sys/kernel/random/uuid
    else
        # Fallback: pure bash random UUID v4
        local hex=$(od -A n -t x1 -N 16 /dev/urandom | tr -d ' \n')
        echo "${hex:0:8}-${hex:8:4}-4${hex:13:3}-$(printf '%x' $(( (0x${hex:16:2} & 0x3F) | 0x80 )) )${hex:18:2}-${hex:20:12}"
    fi
}

UUID="${UUID:-}"
if [ -z "$UUID" ]; then
    UUID=$(generate_uuid)
    echo "⚠️  No UUID provided — auto-generated: $UUID"
fi

# UUID format validation (basic check)
if ! echo "$UUID" | grep -qE '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'; then
    echo "❌ Invalid UUID format: $UUID"
    echo "   Please provide a valid v4 UUID via the UUID env variable."
    exit 1
fi

echo "✅ UUID: $UUID"

# ─────────────────────────────────────────────
# 2. DNS Fix (Apply.Build blocks default DNS)
# ─────────────────────────────────────────────
echo "🔧 Fixing DNS resolution ..."

# Backup and prepend public DNS servers
if [ -f /etc/resolv.conf ]; then
    cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null
    # Prepend Cloudflare + Google DNS (keep existing as fallback)
    EXISTING=$(cat /etc/resolv.conf.bak 2>/dev/null | grep -v '^nameserver' || true)
    printf "nameserver 1.1.1.1\nnameserver 8.8.8.8\nnameserver 1.0.0.1\n%s\n" "$EXISTING" > /etc/resolv.conf
    echo "    Updated /etc/resolv.conf"
fi

# Test DNS resolution
DNS_TEST=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" "https://api.trycloudflare.com" 2>/dev/null || echo "fail")
echo "    DNS test (api.trycloudflare.com): HTTP $DNS_TEST"

if [ "$DNS_TEST" = "fail" ]; then
    echo "    ⚠️  DNS may still be unreachable. Trying /etc/hosts fallback..."
    echo "" >> /etc/resolv.conf
    echo "nameserver 9.9.9.9" >> /etc/resolv.conf
fi

# ─────────────────────────────────────────────
# 3. Environment Variables
# ─────────────────────────────────────────────
INTERNAL_PORT="${INTERNAL_PORT:-8080}"
WS_PATH="${WS_PATH:-/vless}"
TUNNEL_LOG="/tmp/cloudflared.log"
XRAY_CONFIG="/app/config.json"

# ─────────────────────────────────────────────
# 4. Generate Xray Configuration (VLESS + WS)
# ─────────────────────────────────────────────
cat > "$XRAY_CONFIG" <<XRAYEOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${INTERNAL_PORT},
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "level": 0,
            "email": "client@example.com"
          }
        ],
        "decryption": "none",
        "fallbacks": []
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "${WS_PATH}"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
XRAYEOF

echo "✅ Xray config written → $XRAY_CONFIG"

# ─────────────────────────────────────────────
# 4. Start Xray-core in Background
# ─────────────────────────────────────────────
echo "🚀 Starting Xray-core on 127.0.0.1:${INTERNAL_PORT} ..."
xray run -config "$XRAY_CONFIG" &
XRAY_PID=$!

# Brief pause to let Xray bind to the port
sleep 1

# Verify Xray is alive
if ! kill -0 "$XRAY_PID" 2>/dev/null; then
    echo "❌ Xray-core failed to start. Exiting."
    exit 1
fi
echo "✅ Xray-core is running (PID: $XRAY_PID)"

# ─────────────────────────────────────────────
# 5. Start cloudflared Argo Tunnel
# ─────────────────────────────────────────────
echo "🚀 Starting Cloudflare Argo Tunnel ..."
# Capture both stdout and stderr (cloudflared logs to stderr in some versions)
cloudflared tunnel --url "http://127.0.0.1:${INTERNAL_PORT}" \
  --no-autoupdate \
  --loglevel=info \
  >> "$TUNNEL_LOG" 2>&1 &
CF_PID=$!
echo "    cloudflared PID: $CF_PID"

# Brief pause to let cloudflared initialize
sleep 3

# Show initial log output for debugging
echo "    --- Initial cloudflared output: ---"
cat "$TUNNEL_LOG" 2>/dev/null | head -20
echo "    --- End initial output ---"

echo "✅ cloudflared started (PID: $CF_PID)"

# ─────────────────────────────────────────────
# 6. Wait for Tunnel URL (filter api.trycloudflare.com)
# ─────────────────────────────────────────────
echo "⏳ Waiting for Cloudflare Argo Tunnel URL ..."
echo "    (Polling /tmp/cloudflared.log every 2s, max 90s)"

TUNNEL_URL=""
MAX_RETRIES=45
RETRY=0

while [ $RETRY -lt $MAX_RETRIES ]; do
    if [ -f "$TUNNEL_LOG" ] && [ -s "$TUNNEL_LOG" ]; then
        # Method 1: Parse JSON log (newer cloudflared versions)
        # Look for "hostname" field in JSON lines
        CANDIDATE=$(grep -o '"hostname":"[^"]*trycloudflare\.com"' "$TUNNEL_LOG" 2>/dev/null | \
                    head -n 1 | \
                    sed 's/"hostname":"//;s/"//' | \
                    sed 's|api\.||')

        # Method 2: Parse plain text log (older versions)
        if [ -z "$CANDIDATE" ]; then
            CANDIDATE=$(grep -oE 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | \
                        grep -v 'api\.trycloudflare\.com' | \
                        head -n 1 | \
                        sed 's|https://||')
        fi

        # Method 3: Fallback - any trycloudflare.com domain
        if [ -z "$CANDIDATE" ]; then
            CANDIDATE=$(grep -oE '[a-zA-Z0-9.-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | \
                        grep -v 'api\.trycloudflare\.com' | \
                        head -n 1)
        fi

        if [ -n "$CANDIDATE" ]; then
            TUNNEL_URL="https://${CANDIDATE}"
            echo "    ✅ Tunnel URL detected: $TUNNEL_URL (after $((RETRY * 2))s)"
            break
        fi
    fi

    RETRY=$((RETRY + 1))
    if [ $((RETRY % 5)) -eq 0 ]; then
        echo "    ⏱️  Still waiting... ($((RETRY * 2))s / $((MAX_RETRIES * 2))s)"
    fi
    sleep 2
done

if [ -z "$TUNNEL_URL" ]; then
    echo "❌ Failed to obtain tunnel URL within $((MAX_RETRIES * 2)) seconds."
    echo "--- Last 30 lines of cloudflared log: ---"
    tail -n 30 "$TUNNEL_LOG" 2>/dev/null
    echo "--- End of log ---"
    kill "$XRAY_PID" "$CF_PID" 2>/dev/null
    exit 1
fi

# Extract clean domain (remove https://)
TUNNEL_DOMAIN=$(echo "$TUNNEL_URL" | sed 's|https://||')
echo ""
echo "══════════════════════════════════════════════════════"
echo "🌐 Tunnel Domain: $TUNNEL_DOMAIN"
echo "══════════════════════════════════════════════════════"

# ─────────────────────────────────────────────
# 7. Generate & Print VLESS Link
# ─────────────────────────────────────────────
# VLESS link format:
#   vless://UUID@domain:443?encryption=none&security=tls&type=ws&host=DOMAIN&sni=DOMAIN&path=WS_PATH#LABEL
VLESS_LINK="vless://${UUID}@${TUNNEL_DOMAIN}:443?encryption=none&security=tls&type=ws&host=${TUNNEL_DOMAIN}&sni=${TUNNEL_DOMAIN}&path=${WS_PATH}#ApplyBuild-VLESS"

echo ""
echo "══════════════════════════════════════════════════════"
echo "🔗 VLESS Connection Link:"
echo "══════════════════════════════════════════════════════"
echo "$VLESS_LINK"
echo "══════════════════════════════════════════════════════"
echo ""
echo "📋 Client Configuration:"
echo "   Protocol : VLESS"
echo "   Address  : $TUNNEL_DOMAIN"
echo "   Port     : 443"
echo "   UUID     : $UUID"
echo "   Security : tls"
echo "   Network  : ws (WebSocket)"
echo "   Path     : $WS_PATH"
echo "   Host/SNI : $TUNNEL_DOMAIN"
echo ""
echo "⚙️  Save your UUID for future redeploys: $UUID"
echo ""

# ─────────────────────────────────────────────
# 8. Keep Container Alive & Monitor
# ─────────────────────────────────────────────
echo "📡 Services are running. Tunnel URL is live."
echo "    Watching for crashes..."

# Tail the cloudflared log in real-time (BusyBox compatible)
tail -f "$TUNNEL_LOG" &
TAIL_PID=$!

# Wait for any process to exit
wait "$XRAY_PID" "$CF_PID" 2>/dev/null

# Cleanup
kill "$TAIL_PID" 2>/dev/null
echo "⚠️  One of the services stopped. Container exiting."
exit 0
