#!/bin/bash
echo "===== Iniciando CF Football Bypass ====="

# --- Soporte para Docker Secrets estándar con *_FILE ---
if [[ -n "$CF_API_TOKEN_FILE" && -f "$CF_API_TOKEN_FILE" ]]; then
    CF_API_TOKEN=$(cat "$CF_API_TOKEN_FILE")
fi

if [[ -n "$CF_ZONE_ID_FILE" && -f "$CF_ZONE_ID_FILE" ]]; then
    CF_ZONE_ID=$(cat "$CF_ZONE_ID_FILE")
fi

# --- Soporte para ubicación personalizada que tú usas: /run/secrets/... ---
if [ -f "/run/secrets/cf_api_token" ]; then
    CF_API_TOKEN=$(cat /run/secrets/cf_api_token)
fi

if [ -f "/run/secrets/cf_zone_id" ]; then
    CF_ZONE_ID=$(cat /run/secrets/cf_zone_id)
fi
# --- Fin soporte secrets ---

DOMAINS_JSON=${DOMAINS}
INTERVAL=${INTERVAL_SECONDS:-300}
FEED_URL=${FEED_URL:-"https://hayahora.futbol/estado/data.json"}

# Comprobación de variables
if [ -z "$CF_API_TOKEN" ] || [ -z "$CF_ZONE_ID" ]; then
    echo "❌ Error: CF_API_TOKEN y CF_ZONE_ID deben estar configurados"
    exit 1
fi

while true; do
    echo ""
    echo "[$(date '+%F %T')] 🔍 Paso 1: Obteniendo IPs públicas de Cloudflare..."

    MONITOR_IPS=()
    DOMAINS_LIST=()

    for DOMAIN_OBJ in $(echo "$DOMAINS_JSON" | jq -c '.[]'); do
        DOMAIN=$(echo "$DOMAIN_OBJ" | jq -r '.name')
        RECORD=$(echo "$DOMAIN_OBJ" | jq -r '.record // "@"')
        TYPE=$(echo "$DOMAIN_OBJ" | jq -r '.type // "A"')

        FULLNAME="$RECORD.$DOMAIN"
        [ "$RECORD" = "@" ] && FULLNAME="$DOMAIN"

        # Obtener IP pública real usando dig con 1.1.1.1 (Cloudflare resolver)
        IP=$(dig +short "$FULLNAME" @1.1.1.1 | head -n1)

        if [ -n "$IP" ]; then
            MONITOR_IPS+=("$IP")
            DOMAINS_LIST+=("$FULLNAME")
            echo "   ├─ ℹ️ Dominio $FULLNAME listo para monitorizar (IP pública obtenida)"
        else
            echo "   ├─ ⚠️ No se pudo obtener IP pública para $FULLNAME"
        fi
    done

    if [ ${#MONITOR_IPS[@]} -eq 0 ]; then
        echo "[$(date '+%F %T')] ❌ No se pudieron obtener IPs públicas. Reintentando en 60s..."
        sleep 60
        continue
    fi

    echo "[$(date '+%F %T')] 🔍 Paso 2: Consultando feed: $FEED_URL"
    FEED=$(curl -s --max-time 10 "$FEED_URL")
    if [ -z "$FEED" ] || [ "$FEED" = "null" ]; then
        echo "[$(date '+%F %T')] ⚠️ Error al obtener el feed. Reintentando en 60s..."
        sleep 60
        continue
    fi

    echo "[$(date '+%F %T')] 🔍 Paso 3: Buscando coincidencias en el feed..."

    BLOQUEO_DETECTADO=false
    IPS_BLOQUEADAS=()
    DOMAINS_BLOQUEADOS=()

    for i in "${!MONITOR_IPS[@]}"; do
        IP=${MONITOR_IPS[$i]}
        FULLNAME=${DOMAINS_LIST[$i]}

        # Buscar esta IP en el feed
        FOUND=$(echo "$FEED" | jq -c --arg ip "$IP" '.data[] | select(.ip==$ip)')

        if [ -n "$FOUND" ]; then
            LAST_STATE=$(echo "$FOUND" | jq -r '.stateChanges[-1].state')
            ISP=$(echo "$FOUND" | jq -r '.isp')
            DESCRIPTION=$(echo "$FOUND" | jq -r '.description')

            if [ "$LAST_STATE" = "true" ]; then
                echo "   ├─ 🔴 $FULLNAME BLOQUEADO en $ISP ($DESCRIPTION)"
                BLOQUEO_DETECTADO=true
                IPS_BLOQUEADAS+=("$IP")
                DOMAINS_BLOQUEADOS+=("$FULLNAME")
            else
                echo "   ├─ ✅ $FULLNAME OK en $ISP ($DESCRIPTION)"
            fi
        else
            echo "   ├─ ℹ️ $FULLNAME no encontrada en el feed (probablemente no está bloqueada)"
        fi
    done

    echo "[$(date '+%F %T')] 🔍 Paso 4: Decidiendo acción..."

    if [ "$BLOQUEO_DETECTADO" = true ]; then
        echo "[$(date '+%F %T')] ⚽ Bloqueos detectados en: ${DOMAINS_BLOQUEADOS[*]}"
        PROXIED=false
        ACTION_DESC="DESACTIVANDO PROXY"
    else
        echo "[$(date '+%F %T')] ✅ Ningún bloqueo detectado"
        PROXIED=true
        ACTION_DESC="ACTIVANDO PROXY"
    fi

    echo "[$(date '+%F %T')] 🔄 Paso 5: $ACTION_DESC en tus dominios..."

    # Aplicar cambios en Cloudflare
    for DOMAIN_OBJ in $(echo "$DOMAINS_JSON" | jq -c '.[]'); do
        DOMAIN=$(echo "$DOMAIN_OBJ" | jq -r '.name')
        RECORD=$(echo "$DOMAIN_OBJ" | jq -r '.record // "@"')
        TYPE=$(echo "$DOMAIN_OBJ" | jq -r '.type // "A"')

        php /app/manage_dns.php "$DOMAIN" "$RECORD" "$TYPE" "$PROXIED" "$CF_API_TOKEN" "$CF_ZONE_ID"
    done

    echo "[$(date '+%F %T')] ✅ Ciclo completado"
    echo "[$(date '+%F %T')] ⏳ Esperando $INTERVAL segundos antes de volver a comprobar..."
    sleep $INTERVAL
done
