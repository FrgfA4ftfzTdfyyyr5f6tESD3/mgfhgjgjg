#!/bin/bash
# ============================================================
# VLESS-WebSocket — Direct (بدون cloudflared)
# Apply.Build خودش TLS terminate می‌کنه
# ============================================================

set -e

echo "══════════════════════════════════════════════════════"
echo "  VLESS WebSocket — Direct Deploy"
echo "══════════════════════════════════════════════════════"

# ───── ۱. UUID ─────
UUID="${UUID:-}"
if [ -z "$UUID" ]; then
    if [ -r /proc/sys/kernel/random/uuid ]; then
        UUID=$(cat /proc/sys/kernel/random/uuid)
    else
        hex=$(od -A n -t x1 -N 16 /dev/urandom | tr -d ' \n')
        UUID="${hex:0:8}-${hex:8:4}-4${hex:13:3}-a${hex:17:3}-${hex:20:12}"
    fi
    echo "⚠️  Auto-generated UUID: $UUID"
else
    echo "✅ Using UUID: $UUID"
fi

# ───── ۲. Settings ─────
WS_PATH="${WS_PATH:-/vless}"
PORT="${PORT:-8080}"

# ───── ۳. Xray Config ─────
# نکته: Apply.Build TLS رو terminate می‌کنه
# پس ما فقط HTTP plain گوش می‌دیم
XRAY_CONF="/app/config.json"
cat > "$XRAY_CONF" <<XEOF
{
  "log": { "level": "warning" },
  "inbounds": [{
    "port": ${PORT},
    "listen": "0.0.0.0",
    "protocol": "vless",
    "settings": {
      "clients": [{ "id": "${UUID}", "level": 0 }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "security": "none",
      "wsSettings": {
        "path": "${WS_PATH}"
      }
    }
  }],
  "outbounds": [{ "protocol": "freedom", "tag": "direct" }]
}
XEOF
echo "✅ Config: listen 0.0.0.0:${PORT} / path: ${WS_PATH}"

# ───── ۴. Start Xray ─────
echo "🚀 Starting Xray-core ..."
xray run -config "$XRAY_CONF" &
XRAY_PID=$!
sleep 1

if ! kill -0 "$XRAY_PID" 2>/dev/null; then
    echo "❌ Xray failed!"
    exit 1
fi
echo "✅ Xray running (PID: $XRAY_PID)"

# ───── ۵. چاپ لینک ─────
echo ""
echo "══════════════════════════════════════════════════════"
echo "🔗 VLESS Connection Link:"
echo "══════════════════════════════════════════════════════"
echo "vless://${UUID}@YOUR-APP-URL:443?encryption=none&security=tls&type=ws&host=YOUR-APP-URL&sni=YOUR-APP-URL&path=${WS_PATH}#ApplyBuild-VLESS"
echo "══════════════════════════════════════════════════════"
echo ""
echo "⚠️  جای YOUR-APP-URL آدرس اختصاصی اپلیکیشن خودت رو بذار"
echo "    مثلاً: myapp.apply.build"
echo ""
echo "📋 Client Settings:"
echo "   Protocol : VLESS"
echo "   Address  : YOUR-APP-URL"
echo "   Port     : 443"
echo "   UUID     : $UUID"
echo "   Path     : $WS_PATH"
echo ""
echo "💡 UUID رو ذخیره کن: $UUID"
echo ""

# ───── ۶. Keep Alive ─────
echo "📡 Listening on port $PORT ..."
wait "$XRAY_PID"
