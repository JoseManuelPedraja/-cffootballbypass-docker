# ⚽ CF Football Bypass (Docker Edition)

**CF Football Bypass** is a lightweight and fully autonomous Docker container that automatically toggles the **Cloudflare proxy** for your domains based on real-time football (soccer) broadcast blocking status in Spain.

This project reads the official public feed from [hayahora.futbol](https://hayahora.futbol/estado/data.json) and dynamically enables or disables the Cloudflare proxy to keep your domains accessible when certain ISPs block traffic during football matches.

---

## 🧠 How It Works

1. The container fetches the JSON feed from  
   [`https://hayahora.futbol/estado/data.json`](https://hayahora.futbol/estado/data.json)

2. It checks the **most recent state** for the ISP entry where `description` is `"No-IP"`.

3. If the latest state is `true` → football block active →  
   the script **removes** your domains from the Cloudflare proxy (`proxied: false`).

4. If the latest state is `false` → no football block →  
   it **enables** the Cloudflare proxy (`proxied: true`).

5. It repeats this process every `INTERVAL_SECONDS` (default: 300 seconds).

---

## 🔒 Security & Design Principles

- **Immutable feed:**  
  The container is hardcoded to use the official  
  [`https://hayahora.futbol/estado/data.json`](https://hayahora.futbol/estado/data.json)  
  source and will refuse to read any other URL.

- **Uses Docker Secrets:**  
  Cloudflare credentials (`CF_API_TOKEN` and `CF_ZONE_ID`) are stored securely in Docker secrets — never exposed as environment variables.

- **Automatic log rotation:**  
  Logs are rotated and compressed every 7 days to keep storage clean.

- **Stateless and 24/7 reliable:**  
  The container continuously monitors the feed and recovers automatically on restart or crash.

---

## 🧰 Requirements

- Docker 20.10+
- Docker Compose v2+
- A valid **Cloudflare API Token** with `Zone:DNS:Edit` permissions
- Your **Cloudflare Zone ID**

---

## 🛠️ Docker Compose Example

```yaml
version: "3.9"

services:
  cf-bypass:
    image: harlekesp/cf-football-bypass:latest
    container_name: cf-football-bypass
    restart: always
    environment:
      DOMAINS: '[{"name":"casa-carreras.es","record":"@","type":"A"}]'
      INTERVAL_SECONDS: 300
    secrets:
      - cf_api_token
      - cf_zone_id
    volumes:
      - cflogs:/app/logs
    networks:
      - private_network

secrets:
  cf_api_token:
    file: ./cf_api_token.txt
  cf_zone_id:
    file: ./cf_zone_id.txt

volumes:
  cflogs:

networks:
  private_network: