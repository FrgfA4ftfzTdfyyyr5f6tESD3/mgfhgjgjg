FROM alpine:latest

# نصب ابزارهای پایه و ttyd
RUN apk add --no-cache curl bash tar openssl libc6-compat ttyd

WORKDIR /app

EXPOSE 3000

# اضافه شدن آپشن -W برای باز شدن قفل کیبورد و تایپ کردن در ترمینال
CMD ["ttyd", "-p", "3000", "-W", "bash"]
