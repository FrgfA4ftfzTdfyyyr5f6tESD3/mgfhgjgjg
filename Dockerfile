FROM alpine:latest

# ۱. نصب پکیج‌های پایه
RUN apk add --no-cache curl bash tar libc6-compat

WORKDIR /app

# ۲. دانلود مستقیم و تمیز سینگ‌باکس و کلودفلرد
RUN curl -L -s https://github.com/SagerNet/sing-box/releases/download/v1.11.3/sing-box-1.11.3-linux-amd64.tar.gz -o sb.tar.gz && \
    tar -zxf sb.tar.gz && mv sing-box-1.11.3-linux-amd64/sing-box ./ && rm -rf sb.tar.gz sing-box-1.11.3-linux-amd64

RUN curl -L -s https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared && \
    chmod +x cloudflared ./sing-box

# ۳. ساخت کانفیگ جیسون بومی برای وب‌ساکت
RUN echo '{\
  "log": {"level": "info"},\
  "inbounds": [{\
    "type": "vless", "tag": "vless-ws-in", "listen": "::", "listen_port": 8080,\
    "users": [{"uuid": "59a39adf-f549-4794-8055-80ef7496401c"}],\
    "transport": {"type": "ws", "path": "/vless-mammad"}\
  }],\
  "outbounds": [{"type": "direct", "tag": "direct"}]\
}' > config.json

EXPOSE 3000

# ۴. ساخت اسکریپت استارت هوشمند که دامنه‌ی API را سانسور می‌کند و فقط لینک واقعی را می‌گیرد
RUN echo '#!/bin/bash\n\
./sing-box run -c ./config.json &\n\
sleep 2\n\
./cloudflared tunnel --url http://localhost:8080 --no-autoupdate 2>&1 | tee tunnel.log &\n\
echo "⏳ در حال ساخت تونل و استخراج لینک نهایی کلودفلر..."\n\
while true; do\n\
    DOMAIN=$(grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" tunnel.log | grep -v "api.trycloudflare.com" | head -n 1)\n\
    if [ -n "$DOMAIN" ]; then\n\
        echo -e "\\n🎯 ممد سرور با موفقیت زنده شد! لینک کانفیگ گوشی شما:\\n"\n\
        echo "vless://59a39adf-f549-4794-8055-80ef7496401c@www.visa.com.tw:443?encryption=none&security=tls&sni=${DOMAIN#https://}&type=ws&host=${DOMAIN#https://}&path=%2Fvless-mammad#Apply-Tunnel"\n\
        break\n\
    fi\n\
    sleep 2\n\
done\n\
wait -n\n\
' > start.sh && chmod +x start.sh

# ۵. اجرای همزمان و ابدی
CMD ["/bin/bash", "./start.sh"]
