FROM alpine:latest

# ۱. نصب ابزارهای مورد نیاز شبکه و کتابخانه‌های سازگاری لینوکس
RUN apk add --no-cache curl bash tar openssl libc6-compat

WORKDIR /app

# ۲. دانلود مستقیم نسخه رسمی و پایدار سینگ‌باکس و کلودفلرد
RUN curl -L -s https://github.com/SagerNet/sing-box/releases/download/v1.11.3/sing-box-1.11.3-linux-amd64.tar.gz -o sb.tar.gz && \
    tar -zxf sb.tar.gz && mv sing-box-1.11.3-linux-amd64/sing-box ./ && rm -rf sb.tar.gz sing-box-1.11.3-linux-amd64

RUN curl -L -s https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared && \
    chmod +x cloudflared ./sing-box

# ۳. ایجاد فایل تنظیمات بومی برای هسته ارتباطی
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

# ۴. اسکریپت استارت نهایی با لود مستقیم لاگ (حذف آپشن line-buffered که بیزی‌باکس را منفجر می‌کرد)
CMD ./sing-box run -c ./config.json & \
    sleep 2 && \
    echo "⏳ در حال استخراج لینک نهایی کلودفلر از شبکه..." && \
    ./cloudflared tunnel --url http://localhost:8080 --no-autoupdate 2>&1 | while read -r line; do \
        if echo "$line" | grep -q "trycloudflare.com"; then \
            domain=$(echo "$line" | grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com"); \
            echo -e "\n🎯 ممد سرور با موفقیت زنده شد! لینک کانفیگ گوشی شما:\n"; \
            echo "vless://59a39adf-f549-4794-8055-80ef7496401c@www.visa.com.tw:443?encryption=none&security=tls&sni=${domain#https://}&type=ws&host=${domain#https://}&path=%2Fvless-mammad#Apply-Cloudflare"; \
        fi \
    done
