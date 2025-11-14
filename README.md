<div align="center">

# ⚽ CF Football Bypass

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://hub.docker.com/r/harlekesp/cffootballbypass)
[![PHP](https://img.shields.io/badge/php-%23777BB4.svg?style=for-the-badge&logo=php&logoColor=white)](https://www.php.net/)
[![License](https://img.shields.io/badge/license-GNU-blue.svg?style=for-the-badge)](LICENSE)
[![Security Scan](https://img.shields.io/badge/security-scanned-success?style=for-the-badge)](https://github.com/harlekesp/cffootballbypass/security)

**Automatically bypass Spanish football broadcast blocks by intelligently toggling Cloudflare proxy** ⚡

[Features](#-features) • [Quick Start](#-quick-start) • [Configuration](#️-configuration) • [Security](#️-security) • [FAQ](#-faq)

</div>

---

## 🎯 What Does It Do?

**CF Football Bypass** is an autonomous Docker container that **automatically enables/disables Cloudflare proxy** for your domains based on real-time football broadcast blocking status in Spain.

It monitors the official feed from [hayahora.futbol](https://hayahora.futbol) and:

<table>
<tr>
<td width="50%" align="center">
<h3>🔴 Block Detected</h3>
Disables Cloudflare proxy<br/>
Your server responds directly
</td>
<td width="50%" align="center">
<h3>🟢 No Blocks</h3>
Enables Cloudflare proxy<br/>
DDoS protection + CDN active
</td>
</tr>
</table>

---

## ✨ Features

<table>
<tr>
<td width="33%" align="center">

### 🤖 Fully Autonomous
Runs 24/7 without manual intervention

</td>
<td width="33%" align="center">

### 🔒 Secure by Design
Docker secrets + non-root user

</td>
<td width="33%" align="center">

### 🎯 Smart Detection
Only monitors your specific IPs

</td>
</tr>
<tr>
<td width="33%" align="center">

### 📊 Modern Logs
Color-coded output with emojis

</td>
<td width="33%" align="center">

### 🔄 Auto-Recovery
Self-healing on failures

</td>
<td width="33%" align="center">

### 📦 Lightweight
Alpine-based image (~50MB)

</td>
</tr>
</table>

---

## 🚀 Quick Start

### Prerequisites

```bash
✅ Docker 20.10+
✅ Docker Compose v2+
✅ Cloudflare API Token (Zone:DNS:Edit)
✅ Cloudflare Zone ID
```

### 📝 Step 1: Get Cloudflare Credentials

| Credential | Where to find it |
|-----------|-------------------|
| **API Token** | [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens) → Create Token → Edit Zone DNS |
| **Zone ID** | Domain Dashboard → Overview → API section (right column) |

### 🐳 Step 2: Create `docker-compose.yml`

```yaml
version: "3.9"

services:
  cf-bypass:
    image: harlekesp/cffootballbypass:latest
    container_name: cf-football-bypass
    restart: always
    environment:
      CF_API_TOKEN: "your_token_here"
      CF_ZONE_ID: "your_zone_id_here"
      DOMAINS: '[{"name":"example.com","record":"@","type":"A"}]'
      INTERVAL_SECONDS: 300
    volumes:
      - cflogs:/app/logs
    networks:
      - private_network

volumes:
  cflogs:

networks:
  private_network:
```

### ▶️ Step 3: Start Container

```bash
docker-compose up -d
```

### 📋 Step 4: Check Logs

```bash
docker logs -f cf-football-bypass
```

---

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Required | Default | Example |
|----------|-------------|:--------:|---------|---------|
| `CF_API_TOKEN` | Cloudflare API Token | ✅ | - | `aBc123...` |
| `CF_ZONE_ID` | Cloudflare Zone ID | ✅ | - | `a1b2c3...` |
| `DOMAINS` | JSON array of domains | ✅ | `[]` | See below ↓ |
| `INTERVAL_SECONDS` | Check interval (seconds) | ❌ | `300` | `180` |

### 📋 DOMAINS Format

```json
[
  {
    "name": "example.com",
    "record": "@",
    "type": "A"
  },
  {
    "name": "example.com",
    "record": "www",
    "type": "A"
  },
  {
    "name": "example.com",
    "record": "blog",
    "type": "CNAME"
  }
]
```

**Parameters:**

- `name` - Your main domain name
- `record` - Subdomain or `@` for root domain
- `type` - DNS record type (`A`, `AAAA`, `CNAME`, etc.)

> **💡 Tip:** Minify JSON to single line for `docker-compose.yml`

---

## 🔍 How It Works

```
┌─────────────┐
│    START    │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────┐
│ 1️⃣  Fetch public IPs            │
│    using dig @1.1.1.1           │
└──────┬──────────────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│ 2️⃣  Query hayahora.futbol feed  │
│    for blocking status          │
└──────┬──────────────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│ 3️⃣  Check for IP matches        │
│    Is your IP blocked?          │
└──────┬──────────────────────────┘
       │
       ▼
    ┌──┴──┐
    │  ?  │
    └─┬─┬─┘
      │ │
  Yes │ │ No
      │ │
      ▼ ▼
  ┌─────┐ ┌─────┐
  │ 🔴  │ │ 🟢  │
  │ OFF │ │  ON │
  └──┬──┘ └──┬──┘
     │       │
     └───┬───┘
         │
         ▼
   ┌──────────┐
   │ 4️⃣  Update│
   │ Cloudflare│
   └─────┬────┘
         │
         ▼
   ┌──────────┐
   │ 5️⃣  Sleep │
   │ INTERVAL │
   └─────┬────┘
         │
         └──► (repeat from step 1)
```

### 📐 Decision Logic

1. **Fetch public IPs** → Uses `dig @1.1.1.1` (Cloudflare resolver)
2. **Query feed** → Reads `hayahora.futbol/estado/data.json`
3. **Check matches** → Compares your IPs with blocked IPs
4. **Decide action:**
   - ✅ **No block** → `proxied: true` (Cloudflare enabled)
   - 🔴 **Blocked** → `proxied: false` (direct server)
5. **Apply changes** → Updates DNS via Cloudflare API
6. **Wait** → Sleeps `INTERVAL_SECONDS` and repeats

---

## 🛡️ Security

| Feature | Implementation |
|---------|----------------|
| **Immutable feed** | Hardcoded to hayahora.futbol only |
| **No external code** | Doesn't execute third-party scripts |
| **Docker Secrets ready** | Supports secrets, not just env vars |
| **Non-root user** | Runs as UID/GID 1000 (appuser) |
| **Minimal privileges** | Only DNS permissions on Cloudflare |
| **Healthcheck** | Verifies connectivity every 30s |
| **CVE Scanning** | Automatic weekly scans with Trivy |
| **Updated packages** | Alpine 3.21 base with latest patches |

### 🔒 CVE Status

[![Security Scan](https://github.com/harlekesp/cffootballbypass/actions/workflows/security-scan.yml/badge.svg)](https://github.com/harlekesp/cffootballbypass/actions/workflows/security-scan.yml)

All known CVEs are patched or mitigated. See [docs/CVE-MITIGATION.md](docs/CVE-MITIGATION.md) for details.

---

## 📊 Example Logs

```log
╔════════════════════════════════════════════════════════╗
║  ⚽ CF Football Bypass v2.0                            ║
║  Automatic Cloudflare Proxy Management                ║
╚════════════════════════════════════════════════════════╝

[2025-01-15 18:30:00] ✅ SUCCESS  │ Configuration loaded successfully
[2025-01-15 18:30:00] ℹ️  INFO     │ Check interval: 300s
[2025-01-15 18:30:00] ℹ️  INFO     │ Feed URL: https://hayahora.futbol/estado/data.json

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2025-01-15 18:30:01] ℹ️  INFO     │ Starting cycle #1

[2025-01-15 18:30:01] 🔍 STEP     │ Fetching public IPs from your domains...
   ├─ ✓ example.com → 185.199.108.153
   ├─ ✓ www.example.com → 185.199.109.153

[2025-01-15 18:30:02] ✅ SUCCESS  │ IPs obtained: 2 domains monitored

[2025-01-15 18:30:02] 🔍 STEP     │ Querying hayahora.futbol feed...
[2025-01-15 18:30:03] ✅ SUCCESS  │ Feed retrieved successfully

[2025-01-15 18:30:03] 🔍 STEP     │ Analyzing blocking status...
   ├─ 🔴 BLOCKED  │ example.com on Movistar (No-IP)
   ├─ 🟢 FREE     │ www.example.com on Vodafone (Alterna)

[2025-01-15 18:30:04] 🔍 STEP     │ Determining required action...
[2025-01-15 18:30:04] ⚽ BLOCK    │ Blocks detected: 1 domain(s)
   ├─ ⚽ example.com

[2025-01-15 18:30:05] 🔄 ACTION   │ 🔓 DISABLE PROXY on Cloudflare...

   ├─ 🔍 Searching example.com (type: A)
   ├─ ✅ Updated │ example.com 🔒 → 🔓 (IP: 185.199.108.153)

┌─────────────────────────────────────────────────────┐
│ Cycle #1 Summary                                    │
├─────────────────────────────────────────────────────┤
│ Updated: 1  │  No changes: 0  │  Errors: 0          │
└─────────────────────────────────────────────────────┘

[2025-01-15 18:30:06] ✅ SUCCESS  │ Cycle #1 completed
[2025-01-15 18:30:06] ℹ️  INFO     │ Next check in 300s...
```

---

## 🔧 Useful Commands

```bash
# View real-time logs
docker logs -f cf-football-bypass

# View last 100 lines
docker logs --tail 100 cf-football-bypass

# Restart container
docker restart cf-football-bypass

# Stop and remove
docker-compose down

# Update to latest version
docker-compose pull && docker-compose up -d

# View container stats
docker stats cf-football-bypass

# Access shell (debug)
docker exec -it cf-football-bypass sh
```

---

## ❓ FAQ

<details>
<summary><strong>🤔 Why do I need this?</strong></summary>

<br>

Some Spanish ISPs block IP ranges during football broadcasts. This container:

1. Detects when **your Cloudflare IP** is blocked
2. Temporarily disables the proxy
3. Your server responds **directly** (bypassing the block)
4. When the match ends, it re-enables Cloudflare

</details>

<details>
<summary><strong>⚖️ Is this legal?</strong></summary>

<br>

**Yes, completely legal.** This script only:
- ✅ Manages DNS configuration of your own domains
- ✅ Reads a public information feed
- ✅ Doesn't modify, intercept, or redistribute protected content

It's equivalent to manually changing Cloudflare settings, but automated.

</details>

<details>
<summary><strong>🚫 What if my server is also blocked?</strong></summary>

<br>

This script **only helps if**:
- ❌ Your Cloudflare IP is blocked
- ✅ Your direct server IP is NOT blocked

If both are blocked, you'll need:
- VPN on your server
- Server IP change
- Reverse tunnel (ngrok, Cloudflare Tunnel, etc.)

</details>

<details>
<summary><strong>📊 Can I monitor multiple domains?</strong></summary>

<br>

**Absolutely!** Add as many as you need:

```json
[
  {"name":"example.com","record":"@","type":"A"},
  {"name":"example.com","record":"www","type":"A"},
  {"name":"example.com","record":"api","type":"A"},
  {"name":"another-domain.com","record":"@","type":"A"}
]
```

</details>

<details>
<summary><strong>⚠️ What if hayahora.futbol goes down?</strong></summary>

<br>

The container will:
1. Retry every **60 seconds**
2. **Maintain** your current Cloudflare configuration
3. Log the error
4. Auto-recover when the feed returns

</details>

<details>
<summary><strong>🧪 How can I test it works?</strong></summary>

<br>

**Option 1: Wait for a real match**
- Check logs during a LaLiga/Champions League match
- You should see state changes

**Option 2: Manual simulation**
```bash
# View current feed status
curl https://hayahora.futbol/estado/data.json | jq
```

**Option 3: Check healthcheck logs**
```bash
docker inspect --format='{{json .State.Health}}' cf-football-bypass | jq
```

</details>

<details>
<summary><strong>🔄 How often does it check?</strong></summary>

<br>

Default: every **5 minutes** (300 seconds).

You can adjust with `INTERVAL_SECONDS`:
- ⚡ Faster → `180` (3 minutes)
- 🐢 Slower → `600` (10 minutes)

**Recommendation:** Don't go below 60 seconds to avoid API rate limits.

</details>

---

## 🐛 Troubleshooting

### Container won't start

```bash
# Check error logs
docker logs cf-football-bypass

# Verify credentials
docker exec cf-football-bypass env | grep CF_
```

### Not detecting blocks

```bash
# Verify your IPs are in the feed
curl -s https://hayahora.futbol/estado/data.json | jq '.data[] | select(.ip=="YOUR_IP")'

# Check DNS resolution
docker exec cf-football-bypass dig +short example.com @1.1.1.1
```

### Healthcheck failing

```bash
# Verify connectivity
docker exec cf-football-bypass curl -v https://hayahora.futbol/estado/data.json
```

---

## 🤝 Contributing

Contributions are welcome! You can help by:

- 🐛 Reporting bugs via [Issues](https://github.com/harlekesp/cffootballbypass/issues)
- 💡 Suggesting features or improvements
- 🔧 Submitting Pull Requests
- ⭐ Starring the repo if you find it useful
- 📢 Sharing the project

### Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add: AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📜 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

```
MIT License - Copyright (c) 2025 harlekesp
```

---

## 🙏 Acknowledgments

- [hayahora.futbol](https://hayahora.futbol) for maintaining the public feed
- The Docker and Cloudflare communities
- All contributors and bug reporters

---

## ⚠️ Disclaimer

This project is a **DNS automation tool**.

**It does not modify, intercept, or redistribute copyrighted content.**

Users are responsible for compliance with all applicable laws in their jurisdiction.

---

<div align="center">

**Made with ⚽ and ☕ in Spain**

[![GitHub](https://img.shields.io/badge/GitHub-harlekesp-181717?style=flat-square&logo=github)](https://github.com/harlekesp)
[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-harlekesp-0db7ed?style=flat-square&logo=docker&logoColor=white)](https://hub.docker.com/r/harlekesp/cffootballbypass)

[⬆ Back to top](#-cf-football-bypass)


</div>
