#!/bin/bash
set -e

CF_API_TOKEN=$(cat /run/secrets/cf_api_token)
CF_ZONE_ID=$(cat /run/secrets/cf_zone_id)
LOG_FILE="/app/logs/$(date +'%Y-%m-%d').log"

echo "===== Iniciando CF Football Bypass =====" >> "$LOG_FILE"

while true
do
    echo "[$(date)] Consultando feed oficial..." >> "$LOG_FILE"
    FOOTBALL_PRESENT=$(php /app/check_feed.php "$FEED_URL")

    if [ "$FOOTBALL_PRESENT" = "true" ]; then
        echo "[$(date)] ⚽ Bloqueo activo (No-IP = true): quitando proxy de Cloudflare" >> "$LOG_FILE"
        PROXY_STATE="false"
    else
        echo "[$(date)] ✅ Sin bloqueo (No-IP = false): activando proxy de Cloudflare" >> "$LOG_FILE"
        PROXY_STATE="true"
    fi

    for row in $(echo "$DOMAINS" | jq -c '.[]'); do
        NAME=$(echo $row | jq -r '.name')
        RECORD=$(echo $row | jq -r '.record')
        TYPE=$(echo $row | jq -r '.type')

        php /app/manage_dns.php "$NAME" "$RECORD" "$TYPE" "$PROXY_STATE" "$CF_API_TOKEN" "$CF_ZONE_ID" >> "$LOG_FILE" 2>&1
    done

    # Comprimir logs antiguos
    find /app/logs -type f -name "*.log" -mtime +7 -exec gzip {} \;

    echo "[$(date)] Esperando $INTERVAL_SECONDS segundos antes de volver a comprobar..." >> "$LOG_FILE"
    sleep "$INTERVAL_SECONDS"
done
