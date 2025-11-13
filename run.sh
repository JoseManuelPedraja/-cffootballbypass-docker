#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

echo "===== Iniciando CF Football Bypass INTELIGENTE ====="

# --- Leer token/zone desde secret o env ---
CF_API_TOKEN="${CF_API_TOKEN:-}"
CF_ZONE_ID="${CF_ZONE_ID:-}"

if [ -f "/run/secrets/cf_api_token" ]; then
  CF_API_TOKEN=$(cat /run/secrets/cf_api_token)
fi
if [ -f "/run/secrets/cf_zone_id" ]; then
  CF_ZONE_ID=$(cat /run/secrets/cf_zone_id)
fi

DOMAINS_JSON="${DOMAINS:-[]}"
INTERVAL="${INTERVAL_SECONDS:-300}"
FEED_URL="${FEED_URL:-https://hayahora.futbol/estado/data.json}"

# Validación mínima
if [ -z "$CF_API_TOKEN" ] || [ -z "$CF_ZONE_ID" ]; then
  echo "❌ ERROR: CF_API_TOKEN o CF_ZONE_ID no están configurados."
  exit 1
fi

# --- Función: obtener IP pública de Cloudflare para un registro ---
get_cloudflare_ip() {
  local domain="$1"
  local record="$2"
  local type="$3"
  local fullname

  if [ "$record" = "@" ] || [ -z "$record" ]; then
    fullname="$domain"
  else
    fullname="${record}.${domain}"
  fi

  local response
  response=$(curl -sS -w "%{http_code}" --max-time 10 \
    -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?name=${fullname}&type=${type}" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json") || true

  local http_code="${response: -3}"
  local body="${response:0:-3}"

  if [ "$http_code" != "200" ]; then
    echo "   ❌ ERROR HTTP $http_code al consultar Cloudflare para ${fullname}"
    local cf_err
    cf_err=$(echo "$body" | jq -r '.errors[]?.message // empty' 2>/dev/null || true)
    if [ -n "$cf_err" ]; then
      echo "      Cloudflare error: $cf_err"
    fi
    return 1
  fi

  local ip
  ip=$(echo "$body" | jq -r '.result[0].content // empty' 2>/dev/null || true)

  if [ -z "$ip" ]; then
    echo "   ⚠️  No se encontró IP para ${fullname} en Cloudflare"
    return 2
  fi

  printf "%s" "$ip"
}

# --- Iterador de dominios ---
iter_domains() {
  echo "$DOMAINS_JSON" | jq -c '.[]' 2>/dev/null || true
}

# --- Bucle principal ---
while true; do
  echo ""
  echo "[$(date '+%F %T')] 🔍 Paso 1: Obteniendo IPs de Cloudflare..."

  declare -a MONITOR_IPS
  MONITOR_IPS=()

  while IFS= read -r domain_obj; do
    [ -z "$domain_obj" ] && continue
    domain=$(echo "$domain_obj" | jq -r '.name // empty')
    record=$(echo "$domain_obj" | jq -r '.record // "@"')
    type=$(echo "$domain_obj" | jq -r '.type // "A"')
    manual_ip=$(echo "$domain_obj" | jq -r '.manual_ip // empty')

    [ -z "$domain" ] && continue

    if [ -n "$manual_ip" ] && [ "$manual_ip" != "null" ]; then
      echo "   ├─ ${record}.${domain} → ${manual_ip} (manual)"
      MONITOR_IPS+=("$manual_ip")
      continue
    fi

    ip=$(get_cloudflare_ip "$domain" "$record" "$type") || rc=$?; rc=${rc:-0}

    if [ -n "${ip:-}" ]; then
      echo "   ├─ ${record}.${domain} → ${ip} (IP pública Cloudflare)"
      MONITOR_IPS+=("$ip")
    else
      echo "   ├─ ${record}.${domain} → ⚠️  No se pudo obtener IP"
    fi
  done < <(iter_domains)

  if [ ${#MONITOR_IPS[@]} -eq 0 ]; then
    echo "[$(date '+%F %T')] ❌ No se pudieron obtener IPs. Reintentando en 60s..."
    sleep 60
    continue
  fi

  IFS=$'\n' read -r -d '' -a UNIQUE_IPS < <(printf "%s\n" "${MONITOR_IPS[@]}" | sort -u && printf '\0')
  MONITOR_IPS=("${UNIQUE_IPS[@]}")
  echo "[$(date '+%F %T')] 📋 IPs a monitorizar: ${MONITOR_IPS[*]}"

  # --- Paso 2: Obtener feed ---
  echo "[$(date '+%F %T')] 🔍 Paso 2: Consultando feed: $FEED_URL"
  feed_raw=$(curl -sS --max-time 10 "$FEED_URL" || true)
  if [ -z "$feed_raw" ] || [ "$feed_raw" = "null" ]; then
    echo "[$(date '+%F %T')] ⚠️ Error al obtener el feed. Reintentando en 60s..."
    sleep 60
    continue
  fi

  # --- Paso 3: Comprobar IPs ---
  echo "[$(date '+%F %T')] 🔍 Paso 3: Buscando coincidencias..."
  bloqueo_detectado=false
  blocked_ips=()

  for ip in "${MONITOR_IPS[@]}"; do
    matches=$(echo "$feed_raw" | jq -c --arg ip "$ip" '.data[]? | select(.ip == $ip)' 2>/dev/null || true)
    if [ -z "$matches" ]; then
      echo "   ├─ ℹ️ IP $ip OK (no encontrada en feed)"
      continue
    fi
    while IFS= read -r row; do
      isp=$(echo "$row" | jq -r '.isp // "desconocido"')
      description=$(echo "$row" | jq -r '.description // ""')
      last_state=$(echo "$row" | jq -r '.stateChanges[-1].state // "false"')
      if [ "$last_state" = "true" ]; then
        echo "   ├─ 🔴 IP $ip BLOQUEADA en $isp — $description"
        bloqueo_detectado=true
        blocked_ips+=("$ip")
      else
        echo "   ├─ ✅ IP $ip OK en $isp — $description"
      fi
    done <<< "$matches"
  done

  # --- Paso 4: Decidir acción proxied ---
  if [ "$bloqueo_detectado" = true ]; then
    echo "[$(date '+%F %T')] ⚽ BLOQUEO DETECTADO en: ${blocked_ips[*]}"
    PROXIED=false
    ACTION_DESC="DESACTIVANDO PROXY"
  else
    echo "[$(date '+%F %T')] ✅ Ningún bloqueo detectado"
    PROXIED=true
    ACTION_DESC="ACTIVANDO PROXY"
  fi

  # --- Paso 5: Aplicar cambios ---
  echo "[$(date '+%F %T')] 🔄 Paso 5: $ACTION_DESC"
  while IFS= read -r domain_obj; do
    [ -z "$domain_obj" ] && continue
    domain=$(echo "$domain_obj" | jq -r '.name // empty')
    record=$(echo "$domain_obj" | jq -r '.record // "@"')
    type=$(echo "$domain_obj" | jq -r '.type // "A"')
    [ -z "$domain" ] && continue
    php /app/manage_dns.php "$domain" "$record" "$type" "$PROXIED" "$CF_API_TOKEN" "$CF_ZONE_ID" || {
      echo "   ⚠️ manage_dns.php devolvió error para ${record}.${domain}"
    }
  done < <(iter_domains)

  echo "[$(date '+%F %T')] ✅ Ciclo completado"
  echo "[$(date '+%F %T')] ⏳ Esperando ${INTERVAL} segundos..."
  sleep "$INTERVAL"
done
