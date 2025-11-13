#!/bin/bash
echo "===== Iniciando CF Football Bypass ====="

# Leer variables de entorno y secrets
DOMAINS_JSON=${DOMAINS}
INTERVAL=${INTERVAL_SECONDS:-300}
CF_API_TOKEN=$(cat /run/secrets/cf_api_token)
CF_ZONE_ID=$(cat /run/secrets/cf_zone_id)

while true; do
    echo "[$(date)] Consultando feed oficial..."
    FEED=$(curl -s https://hayahora.futbol/estado/data.json)

    # Revisar bloqueos: si algún registro tiene state=true → bloqueo activo
    BLOQUEO=false
    for row in $(echo "$FEED" | jq -c '.data[]'); do
        LAST_STATE=$(echo "$row" | jq -r '.stateChanges[-1].state')
        if [ "$LAST_STATE" = "true" ]; then
            BLOQUEO=true
            break
        fi
    done

    if [ "$BLOQUEO" = true ]; then
        echo "[$(date)] ⚽ Bloqueo activo: quitando proxy de Cloudflare"
        PROXIED=false
    else
        echo "[$(date)] ✅ Sin bloqueo: activando proxy de Cloudflare"
        PROXIED=true
    fi

    # Aplicar cambios a todos los dominios configurados
    for DOMAIN_OBJ in $(echo "$DOMAINS_JSON" | jq -c '.[]'); do
        DOMAIN=$(echo "$DOMAIN_OBJ" | jq -r '.name')
        RECORD=$(echo "$DOMAIN_OBJ" | jq -r '.record')
        TYPE=$(echo "$DOMAIN_OBJ" | jq -r '.type')

        # CORREGIDO: Llamar al archivo correcto
        php /app/manage_dns.php "$DOMAIN" "$RECORD" "$TYPE" "$PROXIED" "$CF_API_TOKEN" "$CF_ZONE_ID"
    done

    echo "[$(date)] Esperando $INTERVAL segundos antes de volver a comprobar..."
    sleep $INTERVAL
done