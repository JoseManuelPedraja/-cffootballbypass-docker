
FROM php:8.4-cli-alpine3.21

LABEL maintainer="harlekesp"
LABEL description="CF Football Bypass - Automatic Cloudflare proxy management"
LABEL version="2.0"

RUN apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache \
        curl \
        busybox \
        busybox-binsh \
        jq \
        bash \
        bind-tools \
        ca-certificates \
        tzdata && \

    rm -rf /var/cache/apk/* /tmp/* /root/.cache

ENV TZ=Europe/Madrid
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /app

COPY run.sh manage_dns.php /app/
RUN chmod +x /app/run.sh && \
    chmod 644 /app/manage_dns.php

RUN mkdir -p /app/logs

RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser -s /bin/bash appuser && \
    chown -R appuser:appuser /app

USER appuser

ENV FEED_URL="https://hayahora.futbol/estado/data.json" \
    DOMAINS="[]" \
    INTERVAL_SECONDS=300 \
    CF_API_TOKEN="" \
    CF_ZONE_ID=""

HEALTHCHECK --interval=30s \
            --timeout=10s \
            --start-period=10s \
            --retries=3 \
    CMD curl -f -s -m 5 https://hayahora.futbol/estado/data.json > /dev/null || exit 1

CMD ["./run.sh"]
