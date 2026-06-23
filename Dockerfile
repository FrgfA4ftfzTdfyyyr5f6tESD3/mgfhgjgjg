FROM alpine:latest

RUN apk add --no-cache curl tar

WORKDIR /app

# دانلود هسته اصلی لینوکس
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then BOX_ARCH="linux-amd64"; else BOX_ARCH="linux-arm64"; fi && \
    curl -L -s https://github.com/SagerNet/sing-box/releases/download/v1.11.3/sing-box-1.11.3-${BOX_ARCH}.tar.gz -o sb.tar.gz && \
    tar -zxf sb.tar.gz && mv sing-box-1.11.3-${BOX_ARCH}/sing-box ./ && \
    chmod +x ./sing-box && rm -rf sb.tar.gz sing-box-1.11.3-${BOX_ARCH}

# کپی کردن مستقیم فایل کانفیگ سالم از گیت‌هاب به داخل کانتینر
COPY config.json ./config.json

# جایگذاری پورت خودکار سیستم و استارت
CMD sed -i "s/8080/$PORT/g" ./config.json && ./sing-box run -c ./config.json
