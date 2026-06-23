FROM alpine:latest

# ۱. نصب ابزارهای مورد نیاز و ttyd (ترمینال تحت وب)
RUN apk add --no-cache curl bash tar openssl libc6-compat ttyd

WORKDIR /app

# ۲. باز کردن پورت اصلی کانتینر
EXPOSE 8080

# ۳. اجرای وب‌شل روی پورتی که Apply.Build به ما می‌دهد
# این دستور ترمینال لینوکس (bash) را مستقیماً روی وب مچ می‌کند
CMD ttyd -p $PORT bash
