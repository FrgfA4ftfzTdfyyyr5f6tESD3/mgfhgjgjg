FROM alpine:latest

# نصب ابزارهای پایه شبکه
RUN apk add --no-cache curl tar

WORKDIR /app

# دانلود نسخه پایدار و رسمی سینگ‌باکس لینوکس
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then BOX_ARCH="linux-amd64"; else BOX_ARCH="linux-arm64"; fi && \
    curl -L -s https://github.com/SagerNet/sing-box/releases/download/v1.11.3/sing-box-1.11.3-${BOX_ARCH}.tar.gz -o sb.tar.gz && \
    tar -zxf sb.tar.gz && mv sing-box-1.11.3-${BOX_ARCH}/sing-box ./ && \
    chmod +x ./sing-box && rm -rf sb.tar.gz sing-box-1.11.3-${BOX_ARCH}

# ایجاد کانفیگ استاندارد VLESS روی پورتی که پلتفرم ابری به ما می‌دهد
RUN echo '{\
  "log": {"level": "info"},\
  "inbounds": [{\
    "type": "vless", "tag": "vless-ws-in", "listen": "::", "listen_port": 8080,\
    "users": [{"uuid": "59a39adf-f549-4794-8055-80ef7496401c"}],\
    "transport": {"type": "ws", "path": "/vless-mammad"}\
  }],\
  "outbounds": [{"type": "direct", "tag": "direct"}]\
}' > ./config.json

# دستور هوشمند برای خواندن پورت متغیر پلتفرم ابری و اجرای مستقیم سینگ‌باکس
CMD sed -i "s/8080/$PORT/g" ./config.json && ./sing-box run -c ./config.json