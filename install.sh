#!/bin/bash

# ۱. تولید UUID استاندارد به صورت بومی با ابزار لینوکس
export UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "59a39adf-f549-4794-8055-80ef7496401c")
echo "Generated UUID: $UUID"

# ۲. تنظیم تمام متغیرهای محیطی مورد نیاز هسته
export NEZHA_SERVER=""
export NEZHA_PORT=""
export NEZHA_KEY=""
export ARGO_DOMAIN=""
export ARGO_AUTH=""
export NAME="idx"
export CFIP="www.visa.com.tw"
export CFPORT=443
export CHAT_ID=""
export BOT_TOKEN=""
export UPLOAD_URL=""

# ۳. تشخیص معماری سیستم و دانلود مستقیم فایل باینری اصلی (کدهای اسکریپت دوم)
ARCH=$(uname -m)
case $ARCH in
    "aarch64" | "arm64" | "arm")  ARCH="arm64" ;;
    "x86_64" | "amd64" | "x86")   ARCH="amd64" ;;
    "s390x" | "s390")             ARCH="s390x" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "📥 Downloading core execution binary for $ARCH..."
curl -so sbx "https://$ARCH.eooce.com/sbsh"
chmod +x sbx

# ۴. اجرای باینری اصلی برای چیدمان فایل‌های پروکسی
./sbx
echo "⚡ Installation finished successfully."