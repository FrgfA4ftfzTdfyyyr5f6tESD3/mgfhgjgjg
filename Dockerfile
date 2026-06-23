FROM node:18-alpine

# ۱. نصب ابزارهای لینوکسی مورد نیاز اسکریپت
RUN apk add --no-cache curl bash tar

WORKDIR /app

# ۲. اجرای مستقیم اسکریپت گیت‌هاب در محیطی که Node و NPM کاملاً آماده هستن
RUN curl -L -s https://raw.githubusercontent.com/byJoey/idx-free/refs/heads/main/install.sh -o install.sh && \
    bash install.sh

# ۳. باز کردن پورت ۳۰۰۰ کانتینر
EXPOSE 3000

# ۴. دستور هوشمند برای لود نهایی پورت و استارت خودکار پروژه‌ت
CMD if [ -f "./config.json" ]; then sed -i "s/8080/$PORT/g" ./config.json; fi && \
    if [ -f "./server.js" ]; then node server.js; else bash install.sh; fi
