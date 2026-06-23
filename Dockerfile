# ============================================================
# VLESS-WebSocket — Direct (بدون cloudflared)
# Target: Apply.Build (PaaS با reverse proxy)
# ============================================================
FROM alpine:latest

# Install dependencies
RUN apk add --no-cache \
    curl \
    bash \
    unzip \
    sed \
    grep \
    ca-certificates

WORKDIR /app

# ────────────────────────────────────────────
# Install Xray-core (latest, linux/amd64)
# ────────────────────────────────────────────
RUN curl -sL "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip" \
      -o /tmp/xray.zip && \
    unzip -q /tmp/xray.zip -d /tmp/xray && \
    cp /tmp/xray/xray /usr/local/bin/xray && \
    chmod +x /usr/local/bin/xray && \
    rm -rf /tmp/xray /tmp/xray.zip

# ────────────────────────────────────────────
# Application
# ────────────────────────────────────────────
COPY entrypoint.sh /app/entrypoint.sh

# Fix CRLF → LF (Windows compatibility)
RUN sed -i 's/\r$//' /app/entrypoint.sh && \
    chmod +x /app/entrypoint.sh

# PORT از پلتفرم Apply.Build تزریق می‌شه
# UUID هم قابل override هست
ENV UUID=""
ENV WS_PATH="/vless"

EXPOSE 8080

CMD ["/app/entrypoint.sh"]
