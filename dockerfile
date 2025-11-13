FROM php:8.2-cli

RUN apt-get update && apt-get install -y \
    curl \
    jq \
    gzip \
    logrotate \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . /app
RUN chmod +x /app/run.sh

RUN mkdir -p /app/logs

# Feed fijo (nadie puede cambiarlo)
ENV FEED_URL="https://hayahora.futbol/estado/data.json"

# Variables configurables
ENV DOMAINS="[]"
ENV INTERVAL_SECONDS=300

CMD ["./run.sh"]
