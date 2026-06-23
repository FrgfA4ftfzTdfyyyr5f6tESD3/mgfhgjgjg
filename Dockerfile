FROM alpine:latest

# نصب ابزارهای پایه لینوکس و شبکه که باینری sbx به آن‌ها نیاز دارد
RUN apk add --no-cache curl bash tar openssl libc6-compat

WORKDIR /app

# کپی کردن اسکریپت یکپارچه به داخل کانتینر
COPY install.sh ./install.sh
RUN chmod +x ./install.sh

# باز کردن پورت ۳۰۰۰ کانتینر
EXPOSE 3000

# اجرای مستقیم اسکریپت برای بیلد و بالا نگه داشتن دائم کانتینر
CMD ["/bin/bash", "./install.sh"]
