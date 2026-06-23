FROM alpine:latest

# نصب ابزارهای پایه و کتابخانه سازگاری باینری‌ها
RUN apk add --no-cache curl bash tar openssl libc6-compat

WORKDIR /app

# کپی کردن اسکریپت به داخل کانتینر
COPY install.sh ./install.sh
RUN chmod +x ./install.sh

# 🧼 دستور جادویی برای حذف تمام کاراکترهای مخرب ویندوزی (\r) از فایل اسکریپت
RUN sed -i 's/\r$//' ./install.sh

# باز کردن پورت ۳۰۰۰ کانتینر
EXPOSE 3000

# اجرای اسکریپت تمیز شده
CMD ["/bin/bash", "./install.sh"]
