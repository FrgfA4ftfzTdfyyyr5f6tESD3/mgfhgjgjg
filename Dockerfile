FROM alpine:latest

# ۱. نصب ابزارهای پایه و ttyd (ترمینال تحت وب)
RUN apk add --no-cache curl bash tar openssl libc6-compat ttyd

WORKDIR /app

# ۲. باز کردن پورت ۳۰۰۰
EXPOSE 3000

# ۳. فرمت استاندارد و تفکیک‌شده برای اجرای دستور ttyd
# با این فرمت، پورت و دستور کاملاً از هم جدا می‌شوند و سیستم گیج نمی‌شود
CMD ["ttyd", "-p", "3000", "bash"]
