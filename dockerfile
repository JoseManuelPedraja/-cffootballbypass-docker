# Usa la versión más reciente de PHP 8.4 Alpine
FROM php:8.4-cli-alpine3.21

# Metadata del contenedor
LABEL maintainer="harlekesp"
LABEL description="CF Football Bypass - Automatic Cloudflare proxy management"
LABEL version="2.0"

# Actualizar sistema base y parchar CVEs conocidos
RUN apk update && \
    apk upgrade --no-cache && \
    # Instalar versiones específicas que parchean los CVEs
    apk add --no-cache \
        'curl>=8.14.1-r3' \
        'tar>=1.35-r4' \
        'busybox>=1.37.0-r20' \
        'busybox-binsh>=1.37.0-r20' \
        jq \
        bash \
        bind-tools \
        ca-certificates \
        tzdata && \
    # Forzar actualización de busybox si existe versión vulnerable
    apk del busybox && \
    apk add --no-cache 'busybox>=1.37.0-r20' && \
    # Limpiar cache
    rm -rf /var/cache/apk/* /tmp/* /root/.cache

# Configurar timezone
ENV TZ=Europe/Madrid
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Configurar directorio de trabajo
WORKDIR /app

# Copiar scripts
COPY run.sh manage_dns.php /app/
RUN chmod +x /app/run.sh && \
    chmod 644 /app/manage_dns.php

# Crear directorio de logs
RUN mkdir -p /app/logs

# Crear usuario no-privilegiado
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser -s /bin/bash appuser && \
    chown -R appuser:appuser /app

# Cambiar a usuario no-root
USER appuser

# Variables de entorno
ENV FEED_URL="https://hayahora.futbol/estado/data.json" \
    DOMAINS="[]" \
    INTERVAL_SECONDS=300 \
    CF_API_TOKEN="" \
    CF_ZONE_ID=""

# Healthcheck mejorado
HEALTHCHECK --interval=30s \
            --timeout=10s \
            --start-period=10s \
            --retries=3 \
    CMD curl -f -s -m 5 https://hayahora.futbol/estado/data.json > /dev/null || exit 1

# Comando de inicio
CMD ["./run.sh"]
