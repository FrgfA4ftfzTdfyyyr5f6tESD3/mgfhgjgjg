FROM alpine:latest

# ۱. نصب ابزارهای پایه برای دانلود و اجرای اسکریپت شل شما
RUN apk add --no-cache curl bash tar

WORKDIR /app

# ۲. اجرای مستقیم همان اسکریپت گیت‌هاب که فرستادی
# این خط اسکریپت را دانلود کرده و کدهای پایه را نصب می‌کند
RUN curl -L -s https://raw.githubusercontent.com/byJoey/idx-free/refs/heads/main/install.sh -o install.sh && \
    bash install.sh

# ۳. باز کردن پورت ۳۰۰۰ برای اتصال کلاینت گوشی شما
EXPOSE 3000

# ۴. دستور نهایی برای تنظیم خودکار پورت و استارت هسته پروکسی
# این خط متغیر پورت پلتفرم را می‌خواند و سینگ‌باکس یا ایکس‌ری نصب‌شده را استارت می‌زند
CMD if [ -f "./config.json" ]; then sed -i "s/8080/$PORT/g" ./config.json; fi && \
    if [ -f "./sing-box" ]; then ./sing-box run -c ./config.json; else bash install.sh; fi
