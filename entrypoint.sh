#!/bin/bash
# ============================================================
# VLESS + Cloudflare Argo Tunnel — Apply.Build Edition
# تطبیق‌یافته از start.txt (CloudShell/VPS) برای محیط PaaS
# ============================================================
# تغییرات نسبت به نسخه اصلی:
#   ۱. Sing-box (Docker) → Xray-core (binary مستقیم)
#   ۲. اضافه شدن فیکس DNS (چون 10.250.0.1 timeout می‌ده)
#   ۳. حذف وابستگی‌های غیرموجود (shred, sudo, docker)
#   ۴. سازگار با BusyBox grep (بدون --line-buffered)
# ============================================================

cleanup() {
    set +e
    echo "⚠️  Shutting down..."
    kill "$CF_PID" 2>/dev/null
    kill "$XRAY_PID" 2>/dev/null
    rm -f "$XRAY_CONF" "$TUNNEL_LOG"
}
trap cleanup EXIT INT TERM

set -e

echo "══════════════════════════════════════════════════════"
echo "  VLESS + Cloudflare Argo Tunnel — Apply.Build"
echo "══════════════════════════════════════════════════════"

# ───── ۱. فیکس DNS (فقط برای Apply.Build) ─────
echo ""
echo "[*] Fixing DNS resolution ..."

if [ -f /etc/resolv.conf ]; then
    cp /etc/resolv.conf /tmp/.resolv_bak 2>/dev/null || true
    EXISTING=$(grep -v '^nameserver' /etc/resolv.conf 2>/dev/null || true)
    printf "nameserver 1.1.1.1\nnameserver 8.8.8.8\nnameserver 1.0.0.1\n%s\n" "$EXISTING" > /etc/resolv.conf
    echo "    ✅ DNS updated → 1.1.1.1, 8.8.8.8, 1.0.0.1"
else
    echo "    ⚠️  No resolv.conf found, skipping DNS fix"
fi

# ───── ۲. تولید UUID ─────
UUID="${UUID:-}"
if [ -z "$UUID" ]; then
    if [ -r /proc/sys/kernel/random/uuid ]; then
        UUID=$(cat /proc/sys/kernel/random/uuid)
    else
        hex=$(od -A n -t x1 -N 16 /dev/urandom | tr -d ' \n')
        UUID="${hex:0:8}-${hex:8:4}-4${hex:13:3}-a${hex:17:3}-${hex:20:12}"
    fi
    echo "    ⚠️  Auto-generated UUID: $UUID"
else
    echo "    ✅ Using provided UUID: $UUID"
fi

# ───── ۳. تنظیمات ─────
RANDOM_PATH="${WS_PATH:-/vless}"
INTERNAL_PORT="8080"
XRAY_CONF="/tmp/.xray_conf_$$"
TUNNEL_LOG="/tmp/.cf_tunnel_$$"

# ───── ۴. ساخت Xray Config ─────
cat > "$XRAY_CONF" <<XEOF
{
  "log": { "level": "warning" },
  "inbounds": [{
    "port": ${INTERNAL_PORT},
    "listen": "127.0.0.1",
    "protocol": "vless",
    "settings": {
      "clients": [{ "id": "${UUID}", "level": 0 }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "security": "none",
      "wsSettings": { "path": "${RANDOM_PATH}" }
    }
  }],
  "outbounds": [{ "protocol": "freedom", "tag": "direct" }]
}
XEOF
echo "    ✅ Xray config created"

# ───── ۵. استارت Xray ─────
echo ""
echo "[*] Starting Xray-core on 127.0.0.1:${INTERNAL_PORT} ..."
xray run -config "$XRAY_CONF" &
XRAY_PID=$!
sleep 1

if ! kill -0 "$XRAY_PID" 2>/dev/null; then
    echo "    ❌ Xray failed to start!"
    exit 1
fi
echo "    ✅ Xray is running (PID: $XRAY_PID)"

# ───── ۶. استارت Cloudflare Tunnel ─────
echo ""
echo "[*] Starting Cloudflare Argo Tunnel ..."
echo "    Requesting quick tunnel on trycloudflare.com ..."

cloudflared tunnel --url "http://127.0.0.1:${INTERNAL_PORT}" \
    --no-autoupdate \
    --loglevel=info \
    > "$TUNNEL_LOG" 2>&1 &
CF_PID=$!
echo "    ✅ cloudflared started (PID: $CF_PID)"

# ───── ۷. انتظار برای URL (مثل start.txt) ─────
echo ""
echo "[*] Waiting for tunnel URL ..."

CLEAN_LINK=""
MAX_RETRIES=60
RETRY=0

while [ $RETRY -lt $MAX_RETRIES ]; do
    if [ -f "$TUNNEL_LOG" ] && [ -s "$TUNNEL_LOG" ]; then
        # ✅ دقیقاً مثل start.txt ولی BusyBox-compatible
        CLEAN_LINK=$(grep -oE 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | \
                     grep -v 'api\.trycloudflare\.com' | \
                     head -n 1 | \
                     sed 's|https://||g' | tr -d '\r ')
    fi

    if [ -n "$CLEAN_LINK" ]; then
        echo "    ✅ Tunnel URL detected after $((RETRY * 2))s: $CLEAN_LINK"
        break
    fi

    RETRY=$((RETRY + 1))
    if [ $((RETRY % 10)) -eq 0 ]; then
        echo "    ⏱️  Still waiting... ($((RETRY * 2))s)"
        tail -n 3 "$TUNNEL_LOG" 2>/dev/null | sed 's/^/        /'
    fi
    sleep 2
done

if [ -z "$CLEAN_LINK" ]; then
    echo "    ❌ Failed to get tunnel URL within $((MAX_RETRIES * 2))s"
    echo ""
    echo "    --- Last 20 lines of log: ---"
    tail -n 20 "$TUNNEL_LOG" 2>/dev/null | sed 's/^/        /'
    echo "    --- End ---"
    echo ""
    echo "    💡 If you see 'i/o timeout' on DNS:"
    echo "       → /etc/resolv.conf wasn't writable or DNS still blocked"
    echo "    💡 If you see 'dial tcp connection refused':"
    echo "       → Xray didn't start properly"
    exit 1
fi

# ───── ۸. چاپ لینک VLESS ─────
VLESS_URL="vless://${UUID}@${CLEAN_LINK}:443?encryption=none&security=tls&type=ws&host=${CLEAN_LINK}&sni=${CLEAN_LINK}&path=${RANDOM_PATH}#ApplyBuild-VLESS"

echo ""
echo "══════════════════════════════════════════════════════"
echo "  🔗 VLESS Connection Link:"
echo "══════════════════════════════════════════════════════"
echo "$VLESS_URL"
echo "══════════════════════════════════════════════════════"
echo ""
echo "  📋 Client Settings:"
echo "     Protocol : VLESS"
echo "     Address  : $CLEAN_LINK"
echo "     Port     : 443"
echo "     UUID     : $UUID"
echo "     Security : tls"
echo "     Network  : ws"
echo "     Path     : $RANDOM_PATH"
echo "     Host/SNI : $CLEAN_LINK"
echo ""
echo "  ⚙️  Save UUID for redeploys: $UUID"
echo ""

# ───── ۹. Keep Alive ─────
echo "[*] Services running. Tunnel is live."
tail -f "$TUNNEL_LOG" &
TAIL_PID=$!

wait "$XRAY_PID" "$CF_PID" 2>/dev/null
kill "$TAIL_PID" 2>/dev/null
echo "⚠️  Service stopped. Exiting."
