# ============================================================
# VLESS-WebSocket + Cloudflare Argo Tunnel
# Target Platform: Apply.Build (Alpine PaaS)
# ============================================================
FROM alpine:latest

# Install system dependencies
# - curl: download binaries
# - bash: run entrypoint script
# - unzip: extract xray archive
# - sed: CRLF cleanup
# - grep: log parsing (BusyBox version, NO --line-buffered)
# - libc6-compat: glibc compatibility for pre-built binaries
# - ca-certificates: HTTPS verification
RUN apk add --no-cache \
    curl \
    bash \
    unzip \
    sed \
    grep \
    libc6-compat \
    ca-certificates

WORKDIR /app

# ============================================================
# Install Xray-core (latest release, linux/amd64)
# ============================================================
RUN ARCHIVE="Xray-linux-64.zip" && \
    curl -sL "https://github.com/XTLS/Xray-core/releases/latest/download/${ARCHIVE}" \
      -o "/tmp/${ARCHIVE}" && \
    unzip -q "/tmp/${ARCHIVE}" -d /tmp/xray && \
    cp /tmp/xray/xray /usr/local/bin/xray && \
    chmod +x /usr/local/bin/xray && \
    rm -rf /tmp/xray "/tmp/${ARCHIVE}"

# ============================================================
# Install cloudflared (latest release, linux/amd64)
# ============================================================
RUN curl -sL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" \
      -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# ============================================================
# Application Setup
# ============================================================
COPY entrypoint.sh /app/entrypoint.sh

# Fix CRLF line endings (Windows → Unix) to prevent:
#   "syntax error near unexpected token"
RUN sed -i 's/\r$//' /app/entrypoint.sh && \
    chmod +x /app/entrypoint.sh

# Environment variables (override at runtime via PaaS dashboard)
ENV INTERNAL_PORT=8080
ENV WS_PATH=/vless
# UUID is auto-generated at runtime if not provided:
#   docker run -e UUID="your-uuid-here" ...

EXPOSE 8080

# Entrypoint
CMD ["/app/entrypoint.sh"]
