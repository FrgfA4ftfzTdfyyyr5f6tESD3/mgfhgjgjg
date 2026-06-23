FROM node:18-alpine

# ۱. نصب ابزارهای لینوکسی مورد نیاز
RUN apk add --no-cache curl bash tar

WORKDIR /app

# ۲. دانلود اسکریپت install.sh
RUN curl -L -s https://raw.githubusercontent.com/byJoey/idx-free/refs/heads/main/install.sh -o install.sh

# ۳. پچ کردن اسکریپت: بخش خراب تولید UUID رو کاملاً حذف می‌کنیم 
# و یک UUID ثابت و معتبر (همان شناسه خودت) رو جایش تزریق می‌کنیم
RUN sed -i 's/Generated UUID:.*$/Generated UUID: 59a39adf-f549-4794-8055-80ef7496401c/' install.sh && \
    sed -i 's/UUID=$(node.*$/UUID="59a39adf-f549-4794-8055-80ef7496401c"/' install.sh

# ۴. حالا اجرای اسکریپت بدون دغدغه و بدون ارور نودجی‌اس
RUN bash install.sh

# ۵. باز کردن پورت ۳۰۰۰ کانتینر
EXPOSE 3000

# ۶. دستور استارت نهایی با پورت خودکار سیستم
CMD if [ -f "./config.json" ]; then sed -i "s/8080/$PORT/g" ./config.json; fi && \
    if [ -f "./server.js" ]; then node server.js; else bash install.sh; fi
