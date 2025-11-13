FROM php:8.4-cli-alpine AS base


RUN apk add --no-cache \
    curl \
    jq \
    bash \
    && rm -rf /var/cache/apk/*

WORKDIR /app


COPY run.sh manage_dns.php /app/
RUN chmod +x /app/run.sh


RUN mkdir -p /app/logs


RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser && \
    chown -R appuser:appuser /app

USER appuser


ENV FEED_URL="https://hayahora.futbol/estado/data.json"
ENV DOMAINS="[]"
ENV INTERVAL_SECONDS=300


HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f https://hayahora.futbol/estado/data.json || exit 1

CMD ["./run.sh"]