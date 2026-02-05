# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TAV Architecture is a **pure infrastructure repository** — no application source code. It defines a containerized platform stack orchestrated via Docker/Podman Compose (`compose.yml`).

## Running the Stack

```bash
# Start all services
docker compose up -d    # or podman-compose up -d

# Rebuild after config changes (e.g., pgbouncer)
docker compose up -d --build

# Force-recreate a single service (needed when only compose.yml command/env changed)
docker compose up -d --force-recreate oauth2-proxy

# View logs
docker compose logs -f [service-name]

# Check service health
docker compose ps
```

**Initial Setup Requirements** (detailed in README.md):
1. Configure `.env` with credentials and secrets
2. Initialize Garage storage (create buckets, keys)
3. Configure Keycloak (create realm 'tav', client 'grafana', test user)
4. Update `.env` with Garage S3 keys and Keycloak client secret

There is no application build step or test suite — this is infrastructure-as-config.

**Performance Testing**: Use `LoadTestExecutionPlan.md` to validate platform performance or re-establish baselines after changes.

## Architecture

**16 services** organized into functional layers:

### Ingress & Auth
- **NGINX** (:8080) — Reverse proxy, routes to all services
- **OAuth2-Proxy** (:4180) — Authentication gateway
- **Keycloak** (:8080) — Identity provider (OIDC)

**Request flow:** Browser → NGINX → OAuth2-Proxy → Keycloak for auth, then NGINX proxies to protected services.

### Data Layer
- **PostgreSQL** (:5432) — Primary relational database (3 DBs: `tav`, `keycloak`, `grafana`)
- **PgBouncer** (:6432) — Connection pooler (session mode)
- **Garage** (:3900 S3, :3903 admin) — S3-compatible object storage (Loki chunks, Nuclio artifacts)

### Event Streaming & Processing
- **NATS** (:4222 client, :8222 monitoring) — Message broker with JetStream (1GB mem, 10GB disk, 1000 max connections)
- **Bento** (:4195) — Stream processor (consumes `events.>` from NATS)

### Serverless Compute
- **Nuclio** (:8070) — FaaS platform, triggered by NATS/HTTP/cron

### Observability Stack
- **Prometheus** (:9090) — Metrics collection (scrapes 7 targets at 30s intervals, 15d retention)
- **Alertmanager** (:9093) — Alert routing
- **Grafana** (:3000) — Dashboards & visualization
- **Loki** (:3100) — Log aggregation (720h retention, S3 backend via Garage)
- **Alloy** — Log collector (ships container logs to Loki)
- **cAdvisor** (:8080) — Container resource metrics
- **Postgres Exporter** (:9187) — PostgreSQL metrics

### Data Flow Patterns
```
Events:    Producer → NATS → Bento → [transform] → destination
Logs:      Containers → Alloy → Loki → Garage (S3)
Metrics:   Services → Prometheus → Grafana
Functions: NATS/HTTP → Nuclio → [process] → NATS/S3/DB
```

## Key Files

- `compose.yml` — All 16 service definitions, networks, volumes
- `.env` — Credentials and secrets (never commit real values)
- `nginx/nginx.conf` — Reverse proxy routing and auth_request config
- `pgbouncer/pgbouncer.ini` — Connection pool settings (session mode, DISCARD ALL)
- `pgbouncer/entrypoint.sh` — Generates userlist.txt from env vars at startup
- `postgres/init.sql` — Creates keycloak and grafana databases on first run
- `nats/nats.conf` — JetStream config (1GB mem, 10GB file, 1MB payload)
- `bento/bento.yaml` — Stream processor pipeline (NATS input → transform → output)
- `loki/loki.yaml` — Log aggregation config (S3 backend, 720h retention)
- `prometheus/prometheus.yml` — Scrape targets (7 jobs at 30s interval)
- `prometheus/alert-rules.yml` — Alert definitions
- `alertmanager/alertmanager.yml` — Alert routing rules
- `garage/garage.toml` — S3 object storage config
- `alloy/config.alloy` — Log collection pipeline
- `grafana/provisioning/` — Datasources and dashboard definitions

**Testing & Documentation**:
- `LoadTestExecutionPlan.md` — Step-by-step load testing procedures
- `TestPlan.md` — Comprehensive test plan with KPIs
- `test-results/` — Load test results, charts, and performance analysis
  - `FINAL-REPORT.md` — Complete performance validation report
  - `charts/` — Performance visualizations (gnuplot)
  - `raw-data/phase{1-5}/` — Detailed test outputs by phase

## Current State & Known Issues

### OAuth2-Proxy ↔ Keycloak (RESOLVED)
OAuth2-Proxy now uses `extra_hosts: "localhost:host-gateway"` to resolve `localhost` to the host machine, allowing it to reach Keycloak's OIDC endpoints. Uses `depends_on: condition: service_healthy` to wait for Keycloak startup.

### NGINX dynamic DNS resolution
`proxy_pass` with static hostnames resolves DNS once at startup. If an upstream container restarts with a new IP, nginx breaks. Current fix: use `set $var hostname; proxy_pass http://$var:port;` to force per-request DNS resolution via the `resolver` directive.

## Load Testing & Performance

The platform has been thoroughly load tested (results in `test-results/`):

**Validated Performance**:
- PostgreSQL: 8,787 TPS (17x above target)
- NGINX: 5,458 req/s (11x above target)
- Prometheus/Loki queries: <10ms (200-500x faster than targets)
- Zero errors across 1.5M+ operations

**Testing Tools Available**:
- `pgbench` - Database load testing
- `wrk` - HTTP benchmarking
- Load test execution plan: `LoadTestExecutionPlan.md`
- Test results & charts: `test-results/FINAL-REPORT.md`

**Performance Baselines** (for monitoring):
- Database TPS should stay >4,400 (alert if <50% of baseline)
- NGINX req/s should stay >2,700
- Query latency should stay <100ms
- Memory usage: Platform uses ~2.2GB at baseline (3.7% of 58GB)

## Common Pitfalls

- **OAuth2-Proxy startup race:** oauth2-proxy depends on Keycloak being fully ready (OIDC discovery endpoint). `restart: unless-stopped` handles this via retries. On Docker, use healthcheck + `condition: service_healthy` instead.
- **PgBouncer pool mode:** Session pooling with `server_reset_query = DISCARD ALL` is required for prepared statement support. Transaction pooling breaks prepared statements.
- **Keycloak connects directly to PostgreSQL** (not through PgBouncer) because it uses JDBC.
- **Podman vs Docker on macOS:** Podman on macOS lacks `host-gateway` support, Docker embedded DNS (`127.0.0.11`), and `condition: service_healthy`. Linux or Docker Desktop avoids these issues.
- **Network name:** Compose project name `tav` + network name `tav` = `tav_tav` as the actual network name.
- **NATS healthcheck shows unhealthy:** Service is functional despite healthcheck status - `wget` not in container image. Healthcheck is cosmetic only.
