# TAV Platform Operations Guide

This document provides detailed installation, configuration, maintenance, and troubleshooting procedures for the TAV Architecture platform.

For a quick-start overview, see the [README.md](../README.md).

---

## Table of Contents

1. [Installation & Configuration](#1-installation--configuration)
2. [Maintenance](#2-maintenance)
3. [Troubleshooting](#3-troubleshooting)
4. [Appendix](#4-appendix)

---

## 1. Installation & Configuration

### 1.1 Prerequisites

**Hardware (minimum)**
- 8 GB RAM (16 GB recommended for full stack)
- 20 GB disk (SSD recommended for Prometheus TSDB and Garage storage)
- 4 CPU cores

**Software**
- Docker 20.10+ with Docker Compose 2.0+ (recommended)
- OR Podman 4.0+ with podman-compose (see [Podman vs Docker](#podman-vs-docker) below)
- Git
- A web browser for Keycloak admin and Grafana dashboards

**Operating System**
- **Linux is strongly recommended.** Docker networking, `host-gateway`, DNS resolution (`127.0.0.11`), and healthcheck-based `depends_on` all work reliably on Linux.
- macOS with Docker Desktop works. macOS with Podman has known networking limitations (see [Podman vs Docker](#podman-vs-docker)).

#### Podman vs Docker

| Feature | Docker (Linux/macOS) | Podman (Linux) | Podman (macOS) |
|---------|---------------------|----------------|----------------|
| Embedded DNS (`127.0.0.11`) | Yes | No (use gateway IP) | No |
| `extra_hosts: host-gateway` | Yes | Yes | No |
| `depends_on: condition: service_healthy` | Yes | Yes | No |
| Container-to-host networking | `host.docker.internal` | Direct (host network) | Via VM (limited) |

If using Podman on macOS, you will need workarounds for DNS resolution and service-to-host connectivity. These are documented in the troubleshooting section.

### 1.2 Initial Setup

#### Step 1: Clone and Configure Environment

```bash
git clone <repository-url>
cd tav-architecture
```

Edit `.env` and set secure values for all credentials:

```bash
# Generate secrets
openssl rand -base64 32   # For OAUTH2_PROXY_COOKIE_SECRET
openssl rand -hex 32      # For Garage RPC secret
openssl rand -base64 24   # For database passwords
```

**Required `.env` variables:**

| Variable | Description | Example |
|----------|-------------|---------|
| `POSTGRES_USER` | PostgreSQL superuser | `tav` |
| `POSTGRES_PASSWORD` | PostgreSQL password | (generate) |
| `POSTGRES_DB` | Main database name | `tav` |
| `KEYCLOAK_ADMIN` | Keycloak admin username | `admin` |
| `KEYCLOAK_ADMIN_PASSWORD` | Keycloak admin password | (generate) |
| `KC_DB_PASSWORD` | Keycloak DB password (same as POSTGRES_PASSWORD) | (generate) |
| `OAUTH2_PROXY_CLIENT_ID` | Keycloak client ID for OAuth2-Proxy | `oauth2-proxy` |
| `OAUTH2_PROXY_CLIENT_SECRET` | Keycloak client secret | (from Keycloak UI) |
| `OAUTH2_PROXY_COOKIE_SECRET` | Session cookie encryption key | (generate with openssl) |
| `LOKI_S3_ACCESS_KEY` | Garage S3 key for Loki | (from Garage CLI) |
| `LOKI_S3_SECRET_KEY` | Garage S3 secret for Loki | (from Garage CLI) |
| `NUCLIO_S3_ACCESS_KEY` | Garage S3 key for Nuclio | (from Garage CLI) |
| `NUCLIO_S3_SECRET_KEY` | Garage S3 secret for Nuclio | (from Garage CLI) |
| `POSTGRES_EXPORTER_PASSWORD` | Monitoring user password | (must match init.sql) |

#### Step 2: Initialize Garage Object Storage

Garage must be initialized before Loki or Nuclio can start.

```bash
# Start Garage and PostgreSQL
docker compose up -d postgres garage
sleep 10

# Assign node to cluster layout
NODE_ID=$(docker compose exec garage /garage -c /etc/garage.toml node id -q)
docker compose exec garage /garage -c /etc/garage.toml layout assign "$NODE_ID" -c 1 -z dc1 -t node1
docker compose exec garage /garage -c /etc/garage.toml layout apply --version 1

# Create buckets
docker compose exec garage /garage -c /etc/garage.toml bucket create tav-storage
docker compose exec garage /garage -c /etc/garage.toml bucket create loki-chunks
docker compose exec garage /garage -c /etc/garage.toml bucket create nuclio-artifacts

# Create Loki access key
docker compose exec garage /garage -c /etc/garage.toml key create loki-key
# Output shows Access Key ID and Secret Key — save these to .env as LOKI_S3_ACCESS_KEY / LOKI_S3_SECRET_KEY

# Grant Loki permissions
docker compose exec garage /garage -c /etc/garage.toml bucket allow --read --write loki-chunks --key loki-key

# Create Nuclio access key
docker compose exec garage /garage -c /etc/garage.toml key create nuclio-key
# Save output to .env as NUCLIO_S3_ACCESS_KEY / NUCLIO_S3_SECRET_KEY

# Grant Nuclio permissions
docker compose exec garage /garage -c /etc/garage.toml bucket allow --read --write nuclio-artifacts --key nuclio-key
```

#### Step 3: Configure Keycloak

```bash
# Start Keycloak
docker compose up -d keycloak
docker compose logs -f keycloak
# Wait until: "Listening on: http://0.0.0.0:8080"
```

Open http://localhost:8080/keycloak/ and log in with admin credentials from `.env`.

**Create the `tav` realm:**
1. Click "Create Realm"
2. Realm name: `tav`
3. Click "Create"

**Create the `oauth2-proxy` client:**
1. Clients → Create client
2. Client ID: `oauth2-proxy`
3. Client type: OpenID Connect → Next
4. Client authentication: **ON**
5. Valid redirect URIs: `http://localhost:8080/oauth2/callback`
6. Web origins: `http://localhost:8080`
7. Save

**Copy the client secret:**
1. Clients → `oauth2-proxy` → Credentials tab
2. Copy "Client secret" → update `.env`: `OAUTH2_PROXY_CLIENT_SECRET=<secret>`

**Create a test user:**
1. Users → Add user
2. Username: `testuser`, Email: `test@example.com`, Email verified: ON
3. Create → Credentials tab → Set password (Temporary: OFF)

#### Step 4: Start the Full Stack

```bash
# Update .env with Garage keys and Keycloak client secret, then:
docker compose up -d

# Verify all services are running
docker compose ps

# Check for errors
docker compose logs --tail=20
```

Navigate to http://localhost:8080/ — you should be redirected to Keycloak login. After authentication, you'll see the Nuclio dashboard (root path).

### 1.3 Service Configuration Reference

#### PostgreSQL

| File | Purpose |
|------|---------|
| `postgres/init.sql` | Creates `keycloak` and `grafana` databases, `postgres_exporter` monitoring user |

- Data persisted in `postgres_data` volume
- Keycloak connects directly to PostgreSQL (bypasses PgBouncer) via JDBC
- The `postgres_exporter` user is created with `pg_monitor` role for metrics

#### PgBouncer

| File | Purpose |
|------|---------|
| `pgbouncer/pgbouncer.ini` | Pool mode, connection limits, databases |
| `pgbouncer/entrypoint.sh` | Generates `userlist.txt` from environment variables |
| `pgbouncer/Dockerfile` | Alpine-based image with pgbouncer package |

**Key parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `pool_mode` | `session` | Must be `session` for prepared statement support |
| `server_reset_query` | `DISCARD ALL` | Cleans session state when connection returns to pool |
| `default_pool_size` | `20` | Server connections per database |
| `max_client_conn` | `100` | Maximum client connections |

**Why session mode?** Transaction pooling breaks prepared statements because different transactions from the same client may hit different backends. Session pooling holds a backend for the entire client session, ensuring prepared statements work.

#### NGINX

| File | Purpose |
|------|---------|
| `nginx/nginx.conf` | Reverse proxy routing, auth_request integration, resolver config |

**Route table:**

| Path | Target | Auth | Notes |
|------|--------|------|-------|
| `/oauth2/` | oauth2-proxy:4180 | No | User-facing OAuth routes |
| `/oauth2/auth` | oauth2-proxy:4180 | No | Internal `auth_request` subrequest (exact match, body stripped) |
| `/keycloak/` | keycloak:8080 | No | Identity provider |
| `/grafana/` | grafana:3000 | Yes | Dashboards |
| `/prometheus/` | prometheus:9090 | Yes | Metrics UI |
| `/alertmanager/` | alertmanager:9093 | Yes | Alert management |
| `/garage/admin/` | garage:3903 | Yes | Storage admin API |
| `/s3/` | garage:3900 | No | S3 API (uses S3 credentials) |
| `/api/` | nuclio-dashboard:8070 | Yes | Nuclio API |
| `/` | nuclio-dashboard:8070 | Yes | Nuclio dashboard (root) |

**Resolver:** Set to `127.0.0.11` for Docker. For Podman, use the network gateway IP (check with `podman network inspect <network> | grep gateway`).

**DNS caching:** When using `set $var hostname; proxy_pass http://$var:port;` pattern, nginx re-resolves DNS per request via the resolver. Without variables, nginx resolves once at startup and caches the IP permanently.

#### Prometheus

| File | Purpose |
|------|---------|
| `prometheus/prometheus.yml` | Scrape targets, intervals, external labels |
| `prometheus/alert-rules.yml` | Alert definitions (15+ rules across 5 groups) |

**Scrape targets:** prometheus, cadvisor (15s), postgres-exporter, alertmanager, garage, nuclio, nats, bento

**Retention:** 15 days (`--storage.tsdb.retention.time=15d`)

**Alert groups:** container_health, postgres_health, service_availability, prometheus_health, garage_health

#### Alertmanager

| File | Purpose |
|------|---------|
| `alertmanager/alertmanager.yml` | Alert routing, receiver configuration, inhibit rules |

**Routing:** Critical alerts → `critical-receiver`, all others → `default-receiver`. Both receivers are templates — configure with actual email/Slack/webhook endpoints for production.

**Inhibit rules:** Critical severity suppresses warning severity for same alertname/cluster/instance.

#### Loki

| File | Purpose |
|------|---------|
| `loki/loki.yaml` | Storage backend (Garage S3), retention, ingestion limits |

**Storage:** S3 via Garage (`garage:3900`, bucket `loki-chunks`, path-style access)

**Retention:** 720h (30 days), compactor deletes expired chunks every 10m

**Ingestion limits:** 4 MB/s rate, 6 MB/s burst, max 500 series per query

#### Alloy

| File | Purpose |
|------|---------|
| `alloy/config.alloy` | Docker log discovery, processing pipeline, Loki output |

Discovers all Docker containers, extracts labels (container name, service, project, image), adds `cluster=tav-platform` label, extracts JSON `level` field, ships to Loki.

Requires Docker socket mount (`/var/run/docker.sock`).

#### Garage

| File | Purpose |
|------|---------|
| `garage/garage.toml` | Storage paths, S3/admin/RPC endpoints, replication, compression |

**Ports:** 3900 (S3 API), 3901 (RPC), 3902 (Web), 3903 (Admin/metrics)

**Replication:** none (single node). Change for multi-node deployments.

**Buckets expected:** `loki-chunks`, `nuclio-artifacts`, `tav-storage`

#### NATS

| File | Purpose |
|------|---------|
| `nats/nats.conf` | Server name, JetStream config, connection limits |

**JetStream:** Enabled, 1 GB memory store, 10 GB file store at `/data/jetstream`

**Limits:** 1 MB max payload, 1000 max connections

**Health:** HTTP monitoring at port 8222, healthcheck at `/healthz`

**Exposed ports:** 4222 (client), 8222 (monitoring) — both accessible from host

#### Bento

| File | Purpose |
|------|---------|
| `bento/bento.yaml` | Input (NATS), processing pipeline, output (stdout), metrics |

**Pipeline:** Subscribes to `events.>` on NATS, adds timestamp, parses JSON, enriches with metadata, outputs to stdout.

**Metrics:** Prometheus endpoint at `0.0.0.0:4195`

**Queue group:** `bento-processors` (load-balanced across multiple Bento instances if scaled)

#### Nuclio

Configured via compose.yml environment variables only (no separate config file).

**Key settings:**
- Platform: `local` (Docker-based)
- Default network: `tav_tav` (must match actual Docker network name)
- S3 storage via Garage for function artifacts
- Requires Docker socket mount

**Deploying functions:** Use the Nuclio dashboard at http://localhost:8080/. Functions must specify `network: tav_tav` in platform attributes to access other services.

#### Grafana

| File | Purpose |
|------|---------|
| `grafana/provisioning/datasources/prometheus.yml` | Prometheus datasource (default) |
| `grafana/provisioning/datasources/loki.yml` | Loki datasource |
| `grafana/provisioning/dashboards/dashboards.yml` | Dashboard provisioning config |
| `grafana/provisioning/dashboards/cadvisor-dashboard.json` | Container metrics dashboard |
| `grafana/provisioning/dashboards/postgres-dashboard.json` | PostgreSQL dashboard |

**Auth:** Proxy mode — X-Email header from OAuth2-Proxy, auto sign-up enabled, all users get Admin role by default.

**Subpath:** Served at `/grafana/` via `GF_SERVER_SERVE_FROM_SUB_PATH=true`.

**Database:** PostgreSQL via PgBouncer (`pgbouncer:6432/grafana`).

---

## 2. Maintenance

### 2.1 Routine Operations

```bash
# Check all service status
docker compose ps

# View logs (all services)
docker compose logs --tail=50

# View logs (specific service, follow)
docker compose logs -f keycloak

# Restart a service
docker compose restart <service-name>

# Stop all services (preserves data)
docker compose down

# Start all services
docker compose up -d
```

### 2.2 Updating Services

```bash
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d

# Verify
docker compose ps
docker compose logs --tail=10
```

**Important:** After updating Keycloak, verify the OAuth2 flow still works by opening http://localhost:8080/ in a private browser window. Keycloak may run database migrations on startup that take time.

After updating Prometheus, check http://localhost:8080/prometheus/targets to verify all scrape targets are up.

### 2.3 Backup & Restore

#### PostgreSQL

```bash
# Backup all databases
docker compose exec postgres pg_dumpall -U tav > backup_all.sql

# Backup specific database
docker compose exec postgres pg_dump -U tav tav > backup_tav.sql
docker compose exec postgres pg_dump -U tav keycloak > backup_keycloak.sql
docker compose exec postgres pg_dump -U tav grafana > backup_grafana.sql

# Restore
docker compose exec -T postgres psql -U tav < backup_all.sql
```

#### Garage (S3 storage)

```bash
# Using aws CLI with Garage
aws --endpoint-url http://localhost:3900 \
    s3 sync s3://loki-chunks ./backup/loki-chunks/

aws --endpoint-url http://localhost:3900 \
    s3 sync s3://nuclio-artifacts ./backup/nuclio-artifacts/
```

#### Configuration files

```bash
tar -czf config-backup-$(date +%Y%m%d).tar.gz \
  .env compose.yml \
  nginx/ pgbouncer/ postgres/ prometheus/ alertmanager/ \
  loki/ alloy/ garage/ nats/ bento/ grafana/
```

#### Volume snapshots

```bash
# List volumes
docker volume ls | grep tav

# Inspect volume location
docker volume inspect tav_postgres_data

# Backup a volume (stop service first for consistency)
docker compose stop postgres
docker run --rm -v tav_postgres_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/postgres_data.tar.gz -C /data .
docker compose start postgres
```

### 2.4 Secret Rotation

#### OAuth2-Proxy cookie secret

```bash
# Generate new secret
openssl rand -base64 32

# Update .env: OAUTH2_PROXY_COOKIE_SECRET=<new-secret>

# Recreate oauth2-proxy
docker compose up -d --force-recreate oauth2-proxy
```

All existing user sessions will be invalidated — users must re-authenticate.

#### Keycloak client secret

1. Open Keycloak admin: http://localhost:8080/keycloak/
2. Navigate to `tav` realm → Clients → `oauth2-proxy` → Credentials → Regenerate
3. Copy new secret → update `.env`: `OAUTH2_PROXY_CLIENT_SECRET=<new-secret>`
4. `docker compose up -d --force-recreate oauth2-proxy`

#### PostgreSQL password

```bash
# 1. Update .env with new password
# 2. Change password in PostgreSQL
docker compose exec postgres psql -U tav -c "ALTER USER tav PASSWORD 'new-password';"

# 3. Restart PgBouncer (re-generates userlist.txt from env)
docker compose up -d --force-recreate pgbouncer

# 4. Restart services that connect via PgBouncer
docker compose restart grafana bento
```

#### Garage tokens

Update the `admin_token` and `metrics_token` in `garage/garage.toml`, then:
```bash
docker compose restart garage
# Update prometheus/prometheus.yml bearer_token for garage scrape job
docker compose restart prometheus
```

### 2.5 Scaling & Performance Tuning

#### PgBouncer

Edit `pgbouncer/pgbouncer.ini`:
```ini
default_pool_size = 30       # Increase for more concurrent queries
max_client_conn = 200        # Increase for more services
```
Rebuild: `docker compose up -d --build pgbouncer`

#### Prometheus retention

Edit compose.yml prometheus command:
```yaml
- '--storage.tsdb.retention.time=30d'   # Increase retention
- '--storage.tsdb.retention.size=10GB'  # Or limit by size
```

#### NATS

Edit `nats/nats.conf`:
```conf
max_connections: 2000
max_payload: 10485760    # 10 MB
jetstream {
    max_mem: 2147483648  # 2 GB
    max_file: 21474836480  # 20 GB
}
```

#### Loki ingestion

Edit `loki/loki.yaml` under `limits_config`:
```yaml
ingestion_rate_mb: 8
ingestion_burst_size_mb: 12
```

### 2.6 Log Management

Loki retention is controlled in `loki/loki.yaml`:
```yaml
limits_config:
  retention_period: 720h  # 30 days
```

Monitor disk usage:
```bash
docker system df -v | grep tav
du -sh /var/lib/docker/volumes/tav_*
```

### 2.7 TLS/HTTPS (Production)

For production, add TLS termination at NGINX. Update `nginx/nginx.conf`:

```nginx
server {
    listen 443 ssl;
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    # ... existing location blocks ...
}
server {
    listen 80;
    return 301 https://$host$request_uri;
}
```

Mount certificates in compose.yml:
```yaml
nginx:
  volumes:
    - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    - ./nginx/ssl:/etc/nginx/ssl:ro
```

Update all `localhost:8080` references to your domain in:
- `.env` → `OAUTH2_PROXY_REDIRECT_URL`, `OAUTH2_PROXY_COOKIE_SECRET`
- `compose.yml` → Keycloak `KC_HOSTNAME`, OAuth2-Proxy `--redirect-url`, Grafana `GF_SERVER_ROOT_URL`
- Set `--cookie-secure=true` in oauth2-proxy

---

## 3. Troubleshooting

Each section follows: **Symptom → Diagnosis → Root Cause → Fix → Verification**

### 3.1 Authentication Flow Failures

#### OAuth2-Proxy can't reach Keycloak (OIDC discovery failure)

**Symptom:** OAuth2-proxy logs show repeated errors:
```
ERROR: Failed to initialise OAuth2 Proxy: error initialising provider:
could not create provider data: error building OIDC ProviderVerifier:
failed to discover OIDC configuration: dial tcp ...:8080: connect: connection refused
```

**Diagnosis:**
```bash
docker compose logs oauth2-proxy | grep -i error
```

**Root Cause:** OAuth2-proxy starts before Keycloak is ready. `depends_on` only waits for the container to start, not for the application to be ready.

**Fix (Docker):** Add healthcheck to Keycloak and conditional depends_on:
```yaml
keycloak:
  healthcheck:
    test: ["CMD-SHELL", "/opt/keycloak/bin/kc.sh show-config > /dev/null 2>&1 || exit 1"]
    interval: 10s
    timeout: 5s
    retries: 30
    start_period: 60s

oauth2-proxy:
  depends_on:
    keycloak:
      condition: service_healthy
```

**Fix (Podman without healthcheck support):** Rely on `restart: unless-stopped` — oauth2-proxy will crash and retry until Keycloak is ready. This is noisy but functional.

**Verification:** `docker compose logs oauth2-proxy | tail -5` should show `OAuthProxy configured for Keycloak OIDC Client ID: oauth2-proxy`.

---

#### Token exchange fails (localhost not reachable from container)

**Symptom:** Login redirects to Keycloak, credentials accepted, but callback returns 500. Logs show:
```
Error redeeming code during OAuth2 callback: token exchange failed:
Post "http://localhost:8080/keycloak/realms/tav/protocol/openid-connect/token":
dial tcp [::1]:8080: connect: connection refused
```

**Diagnosis:**
```bash
docker compose logs oauth2-proxy | grep "Error redeeming"
```

**Root Cause:** Keycloak's OIDC discovery document advertises `http://localhost:8080/...` as its token endpoint (based on `KC_HOSTNAME`). OAuth2-proxy uses these discovered URLs for the token exchange. From inside the container, `localhost` refers to the container itself, not the host.

**Fix (Docker on Linux):** Add `extra_hosts` to oauth2-proxy in compose.yml:
```yaml
oauth2-proxy:
  extra_hosts:
    - "localhost:host-gateway"
```
This maps `localhost` inside the container to the host machine, where nginx listens on port 8080.

**Fix (alternative — any platform):** Route through nginx internally. Set:
```yaml
- --oidc-issuer-url=http://nginx/keycloak/realms/tav
- --insecure-oidc-skip-issuer-verification=true
```
OAuth2-proxy discovers endpoints via nginx (port 80, internal network), and the issuer mismatch is ignored.

**Important:** The `keycloak-oidc` provider ignores `--redeem-url` overrides — it always uses URLs from the OIDC discovery document. The `--oidc-issuer-url` or `extra_hosts` approach is required.

**Verification:** Complete a login flow end-to-end. After Keycloak credentials, you should be redirected to the application (not a 500 error page).

---

#### Keycloak realm or client not configured

**Symptom:** OAuth2-proxy logs show 404 or "realm does not exist" during OIDC discovery.

**Diagnosis:**
```bash
# Test OIDC discovery endpoint directly
docker compose exec nginx wget -qO- http://keycloak:8080/keycloak/realms/tav/.well-known/openid-configuration
```

**Root Cause:** The `tav` realm or `oauth2-proxy` client hasn't been created in Keycloak.

**Fix:** Follow [Step 3: Configure Keycloak](#step-3-configure-keycloak) in the installation section.

**Verification:** The wget command above returns a JSON document with `issuer`, `token_endpoint`, etc.

---

#### Cookie/session issues (redirect loops)

**Symptom:** Browser shows redirect loop between oauth2-proxy and Keycloak, or "too many redirects" error.

**Diagnosis:** Clear browser cookies for `localhost:8080` and try in a private window.

**Root Cause:** Stale or corrupted OAuth2-proxy session cookies, or cookie domain mismatch.

**Fix:**
1. Clear browser cookies
2. Verify `--cookie-domain` matches the domain you're accessing (e.g., `localhost`)
3. Verify `--cookie-secure=false` for HTTP (non-TLS) setups
4. Restart oauth2-proxy: `docker compose restart oauth2-proxy`

---

### 3.2 NGINX / Proxy Issues

#### DNS caching (stale upstream IPs after container restart)

**Symptom:** NGINX returns 502/504 after a backend container restarts. Logs show:
```
connect() failed (113: Host is unreachable) while connecting to upstream
```

**Diagnosis:** The upstream IP in the error log doesn't match the current container IP:
```bash
docker inspect <container> --format '{{.NetworkSettings.Networks}}'
```

**Root Cause:** NGINX resolves DNS once at startup when `proxy_pass` uses a static hostname. After a container restarts with a new IP, NGINX still uses the old IP.

**Fix:** Use variables in `proxy_pass` to force per-request DNS resolution:
```nginx
resolver 127.0.0.11 valid=30s;  # Docker DNS

location /grafana/ {
    set $grafana grafana;
    proxy_pass http://$grafana:3000;
    # ...
}
```

Or restart NGINX after upstream container restarts:
```bash
docker compose restart nginx
```

**Verification:** `curl -I http://localhost:8080/grafana/` returns 200 or 302 (redirect to login).

---

#### Resolver configuration (Docker vs Podman)

**Symptom:** NGINX logs show:
```
send() failed (111: Connection refused) while resolving, resolver: 127.0.0.11:53
```

**Root Cause:** `127.0.0.11` is Docker's embedded DNS. Podman uses a different DNS (aardvark-dns on the network gateway).

**Fix for Podman:**
```bash
# Find the gateway IP
podman network inspect <network-name> | grep gateway
# e.g., 10.89.1.1
```
Update `nginx.conf`:
```nginx
resolver 10.89.1.1 valid=30s;
```

---

#### auth_request returns 502

**Symptom:** All protected pages return 500. NGINX logs:
```
auth request unexpected status: 502 while sending to client
```

**Diagnosis:** The `auth_request` subrequest to `/oauth2/auth` is failing. Check oauth2-proxy:
```bash
docker compose logs oauth2-proxy | tail -20
docker compose ps oauth2-proxy
```

**Root Cause:** OAuth2-proxy is down or unreachable.

**Fix:** Restart oauth2-proxy. If it keeps crashing, check its logs for the initialization error (usually Keycloak connectivity).

---

### 3.3 Database Issues

#### PgBouncer prepared statement errors

**Symptom:** Application logs show:
```
ERROR: unnamed prepared statement does not exist
```
or:
```
ERROR: bind message supplies N parameters, but prepared statement "" requires M
```

**Root Cause:** PgBouncer is in `transaction` pool mode. Prepared statements are session-level state that gets lost when the connection is returned to the pool between transactions.

**Fix:** Set session pooling with state cleanup in `pgbouncer/pgbouncer.ini`:
```ini
pool_mode = session
server_reset_query = DISCARD ALL
```
Rebuild: `docker compose up -d --build pgbouncer`

**Verification:**
```bash
docker compose exec pgbouncer psql -U tav -d tav -c "PREPARE test AS SELECT 1; EXECUTE test; DEALLOCATE test;"
```

---

#### Connection exhaustion

**Symptom:** Applications get connection errors. PgBouncer logs show "no more connections allowed".

**Diagnosis:**
```bash
# Check PgBouncer pool status
docker compose exec pgbouncer psql -U tav -p 6432 -d pgbouncer -c "SHOW POOLS;"
docker compose exec pgbouncer psql -U tav -p 6432 -d pgbouncer -c "SHOW CLIENTS;"

# Check PostgreSQL connections
docker compose exec postgres psql -U tav -c "SELECT count(*) FROM pg_stat_activity;"
```

**Fix:** Increase limits in `pgbouncer/pgbouncer.ini`:
```ini
default_pool_size = 30
max_client_conn = 200
```

Also check PostgreSQL's `max_connections` (default 100). Increase if needed via compose.yml:
```yaml
postgres:
  command: postgres -c max_connections=200
```

---

#### PostgreSQL won't start

**Symptom:** Postgres container exits immediately or is stuck in restart loop.

**Diagnosis:**
```bash
docker compose logs postgres | tail -30
```

**Common causes:**
- **Corrupt data:** `FATAL: could not open file "..." No such file or directory` → Restore from backup, or `docker compose down -v` to recreate (loses data)
- **Disk full:** `PANIC: could not write to file ... No space left on device` → Free disk space, clean old Docker images: `docker image prune -a`
- **Permission issues:** Check volume ownership

---

### 3.4 Monitoring Issues

#### Prometheus targets down

**Symptom:** Alerts firing for `PrometheusTargetDown`. Prometheus UI shows targets as DOWN.

**Diagnosis:** Open http://localhost:8080/prometheus/targets and check which targets show errors.

**Common causes:**
- Service not running: `docker compose ps <service>`
- Wrong port/endpoint in `prometheus/prometheus.yml`
- Service takes time to start (wait and check again)
- Network issue: verify service is on the `tav` network

---

#### Loki not receiving logs

**Symptom:** Grafana Explore with Loki datasource shows no logs.

**Diagnosis chain:**
```bash
# 1. Check Alloy is collecting
docker compose logs alloy | tail -20

# 2. Check Loki is receiving
docker compose logs loki | grep -i error

# 3. Check Garage is accessible from Loki
docker compose exec loki wget -qO- http://garage:3900/ 2>&1
```

**Common causes:**
- Alloy can't access Docker socket (check volume mount)
- Loki can't reach Garage (Garage not initialized, wrong S3 credentials)
- Garage bucket doesn't exist (run Garage initialization steps)
- Loki S3 keys in `.env` don't match Garage keys

**Fix:** Work through the chain — Alloy → Loki → Garage. Fix the first broken link.

---

#### Grafana can't connect to datasources

**Symptom:** Grafana dashboards show "No data" or datasource errors.

**Diagnosis:** Go to Grafana → Configuration → Data Sources → Test each datasource.

**Common causes:**
- Prometheus/Loki not running
- Wrong URL in provisioning files (check `grafana/provisioning/datasources/`)
- PgBouncer not running (Grafana uses PostgreSQL for its own database)

---

### 3.5 Storage Issues

#### Garage cluster not initialized

**Symptom:** Loki logs show S3 connection errors. Garage returns empty bucket lists.

**Diagnosis:**
```bash
docker compose exec garage /garage -c /etc/garage.toml status
docker compose exec garage /garage -c /etc/garage.toml layout show
docker compose exec garage /garage -c /etc/garage.toml bucket list
```

**Root Cause:** Garage requires manual cluster initialization (layout assignment and bucket creation) after first start.

**Fix:** Follow [Step 2: Initialize Garage](#step-2-initialize-garage-object-storage).

---

#### Disk space (volumes filling up)

**Symptom:** Services crash or fail to write. Docker logs show "No space left on device".

**Diagnosis:**
```bash
docker system df -v
df -h
du -sh /var/lib/docker/volumes/tav_*
```

**Fix:**
```bash
# Remove unused images
docker image prune -a

# Reduce Prometheus retention
# Edit compose.yml: --storage.tsdb.retention.time=7d

# Reduce Loki retention
# Edit loki/loki.yaml: retention_period: 168h  (7 days)

# Clean Docker build cache
docker builder prune
```

---

### 3.6 Networking Issues

#### Container DNS resolution failures

**Symptom:** A service can't connect to another by hostname. Logs show "Name or service not known" or "No such host".

**Diagnosis:**
```bash
# Check containers are on the same network
docker network inspect tav_tav

# Test DNS from inside a container
docker compose exec nginx nslookup keycloak
```

**Root Cause:** Containers not on the same Docker network, or DNS resolver issue.

**Fix:** Verify all services have `networks: [tav]` in compose.yml.

---

#### Port conflicts

**Symptom:** `docker compose up` fails with "port is already allocated" or "address already in use".

**Diagnosis:**
```bash
# Find what's using the port
lsof -i :8080
# or
ss -tlnp | grep 8080
```

**Fix:** Stop the conflicting process, or change the port mapping in compose.yml:
```yaml
nginx:
  ports:
    - "9080:80"  # Changed from 8080 to 9080
```

Update all `localhost:8080` references in `.env` and compose.yml accordingly.

---

### 3.7 Nuclio Issues

#### Functions can't connect to services (NATS, PostgreSQL)

**Symptom:** Deployed Nuclio function fails to connect to `nats:4222` or `pgbouncer:6432`.

**Root Cause:** Nuclio functions run as separate Docker containers. They must be on the same network as the platform services.

**Fix:** In the function spec, set the network:
```yaml
platform:
  attributes:
    network: tav_tav
```

The `NUCLIO_DASHBOARD_PLATFORM_CONFIGURATION_LOCAL_DEFAULT_NETWORK` environment variable in compose.yml should match the actual network name (check with `docker network ls | grep tav`).

---

### 3.8 NATS / Bento Issues

#### NATS health check failing

**Diagnosis:**
```bash
curl http://localhost:8222/healthz
curl http://localhost:8222/varz | jq '.connections'
docker compose logs nats | tail -20
```

#### Messages not reaching Bento

**Symptom:** Messages published to NATS don't appear in Bento logs.

**Diagnosis:**
```bash
# Check Bento is running
docker compose ps bento

# Check Bento logs for connection errors
docker compose logs bento | grep -i error

# Verify NATS subject matches
# Bento subscribes to: events.>
# Publish to: events.test (must start with "events.")
nats pub -s localhost:4222 events.test '{"hello": "world"}'
```

**Common causes:**
- Bento not connected to NATS (check logs)
- Wrong NATS subject (must match `events.>` pattern)
- NATS not ready when Bento started (restart Bento)

---

## 4. Appendix

### 4.1 Port Reference

| Port | Service | Protocol | Exposed to Host | Description |
|------|---------|----------|-----------------|-------------|
| 80 | NGINX | HTTP | 8080 | Main ingress |
| 5432 | PostgreSQL | TCP | No | Database |
| 6432 | PgBouncer | TCP | No | Connection pool |
| 8080 | Keycloak | HTTP | No (via NGINX) | Identity provider |
| 4180 | OAuth2-Proxy | HTTP | No (via NGINX) | Auth proxy |
| 3000 | Grafana | HTTP | No (via NGINX) | Dashboards |
| 9090 | Prometheus | HTTP | No (via NGINX) | Metrics |
| 9093 | Alertmanager | HTTP | No (via NGINX) | Alerts |
| 3100 | Loki | HTTP | No | Log aggregation |
| 12345 | Alloy | HTTP | No | Metrics/health |
| 3900 | Garage S3 | HTTP | No (via NGINX) | Object storage API |
| 3901 | Garage RPC | TCP | No | Internal replication |
| 3902 | Garage Web | HTTP | No | Web hosting |
| 3903 | Garage Admin | HTTP | No (via NGINX) | Admin API / metrics |
| 8070 | Nuclio | HTTP | No (via NGINX) | Serverless dashboard |
| 4222 | NATS | TCP | Yes | Message broker |
| 8222 | NATS | HTTP | Yes | Monitoring |
| 4195 | Bento | HTTP | No | Metrics |
| 8080 | cAdvisor | HTTP | No | Container metrics |
| 9187 | Postgres Exporter | HTTP | No | DB metrics |

### 4.2 Environment Variable Reference

| Variable | Used By | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | postgres, pgbouncer, bento | Database username |
| `POSTGRES_PASSWORD` | postgres, pgbouncer, grafana, bento | Database password |
| `POSTGRES_DB` | postgres | Main database name |
| `KEYCLOAK_ADMIN` | keycloak | Admin console username |
| `KEYCLOAK_ADMIN_PASSWORD` | keycloak | Admin console password |
| `KC_DB_PASSWORD` | keycloak | Keycloak's database password |
| `OAUTH2_PROXY_CLIENT_ID` | oauth2-proxy | Keycloak OIDC client ID |
| `OAUTH2_PROXY_CLIENT_SECRET` | oauth2-proxy | Keycloak OIDC client secret |
| `OAUTH2_PROXY_COOKIE_SECRET` | oauth2-proxy | Cookie encryption key (32 bytes base64) |
| `LOKI_S3_ACCESS_KEY` | loki | Garage S3 access key for Loki |
| `LOKI_S3_SECRET_KEY` | loki | Garage S3 secret key for Loki |
| `NUCLIO_S3_ACCESS_KEY` | nuclio-dashboard | Garage S3 access key for Nuclio |
| `NUCLIO_S3_SECRET_KEY` | nuclio-dashboard | Garage S3 secret key for Nuclio |
| `POSTGRES_EXPORTER_PASSWORD` | postgres-exporter | Monitoring user password |

### 4.3 Useful Commands Cheat Sheet

```bash
# ── Service Management ──────────────────────────
docker compose up -d                     # Start all
docker compose down                      # Stop all (keep data)
docker compose down -v                   # Stop all + delete volumes (DESTROYS DATA)
docker compose restart <service>         # Restart one service
docker compose up -d --force-recreate <service>  # Recreate with new config
docker compose up -d --build pgbouncer   # Rebuild custom image

# ── Logs ────────────────────────────────────────
docker compose logs -f <service>         # Follow logs
docker compose logs --tail=50            # Last 50 lines (all)
docker compose logs --since 1h           # Last hour

# ── Database ────────────────────────────────────
docker compose exec postgres psql -U tav -d tav
docker compose exec pgbouncer psql -U tav -p 6432 -d pgbouncer -c "SHOW POOLS;"
docker compose exec postgres pg_dump -U tav tav > backup.sql

# ── Garage ──────────────────────────────────────
docker compose exec garage /garage -c /etc/garage.toml status
docker compose exec garage /garage -c /etc/garage.toml bucket list
docker compose exec garage /garage -c /etc/garage.toml key list

# ── NATS ────────────────────────────────────────
curl http://localhost:8222/varz | jq     # Server info
curl http://localhost:8222/jsz | jq      # JetStream status
nats pub -s localhost:4222 events.test '{"key":"value"}'
nats sub -s localhost:4222 "events.>"

# ── Monitoring ──────────────────────────────────
curl http://localhost:8080/prometheus/targets  # Scrape targets (via browser)
docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml

# ── NGINX ───────────────────────────────────────
docker compose exec nginx nginx -t       # Test config
docker compose exec nginx nginx -s reload  # Reload without restart

# ── Disk ────────────────────────────────────────
docker system df -v                      # Docker disk usage
docker image prune -a                    # Remove unused images
docker volume ls | grep tav              # List platform volumes
```

### 4.4 Architecture Diagram

See [documents/Architecture.png](Architecture.png) and [documents/Architecture.md](Architecture.md) for the visual architecture diagram and component descriptions.
