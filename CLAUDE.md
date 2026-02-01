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
```

There is no build step, test suite, or linter — this is infrastructure-as-config.

## Architecture

**Request flow:** Browser → NGINX (:8080) → OAuth2-Proxy (:4180) → Keycloak (:8080) for auth, then NGINX proxies to Grafana (:3000).

**Key paths in NGINX:**
- `/` → Grafana (protected by `auth_request` to OAuth2-Proxy)
- `/oauth2/` → OAuth2-Proxy (user-facing OAuth routes: login, callback, sign_out)
- `/oauth2/auth` → OAuth2-Proxy (internal-only `auth_request` subrequest, exact match, body stripped)
- `/keycloak/` → Keycloak

**Database flow:** Services → PgBouncer (:6432) → PostgreSQL (:5432). Three databases: `tav`, `keycloak`, `grafana`.

**Planned/documented services not yet in compose.yml:** Prometheus, Alertmanager, cAdvisor, Loki, Alloy, Garage, NATS, Bento, Nuclio, Postgres Exporter. See `documents/Architecture.md` for descriptions.

## Key Files

- `compose.yml` — All service definitions, networks, volumes
- `.env` — Credentials and secrets (never commit real values)
- `nginx/nginx.conf` — Reverse proxy routing and auth_request config
- `pgbouncer/pgbouncer.ini` — Connection pool settings (session mode, DISCARD ALL)
- `pgbouncer/entrypoint.sh` — Generates userlist.txt from env vars at startup
- `postgres/init.sql` — Creates keycloak and grafana databases on first run

## Current State & Known Issues

### OAuth2-Proxy ↔ Keycloak token exchange (IN PROGRESS)
The core problem: Keycloak advertises `http://localhost:8080/keycloak/realms/tav` as its issuer/token endpoint (via `KC_HOSTNAME`). OAuth2-proxy's `keycloak-oidc` provider ignores `--redeem-url` overrides and uses the discovered endpoints. From inside a container, `localhost` doesn't reach the host.

**Current config:** `--oidc-issuer-url=http://nginx/keycloak/realms/tav` routes OIDC discovery through nginx internally. This has NOT been tested yet.

**On Linux (target platform):** Simpler fixes are available:
- `extra_hosts: "localhost:host-gateway"` works on Linux Podman/Docker
- Docker supports `host.docker.internal` natively
- `depends_on` with `condition: service_healthy` works on Docker
- DNS resolver `127.0.0.11` works on Docker (currently hardcoded to `10.89.1.1` for Podman macOS)

**When moving to Linux Docker, consider reverting:**
1. `nginx.conf` resolver back to `127.0.0.11`
2. `--oidc-issuer-url` back to `http://keycloak:8080/keycloak/realms/tav` (with `extra_hosts: host-gateway` or direct internal routing)
3. Add Keycloak healthcheck + `depends_on: condition: service_healthy` for oauth2-proxy
4. nginx `proxy_pass` can use static hostnames again (no need for `set $var` trick) since Docker DNS at `127.0.0.11` works reliably

### NGINX dynamic DNS resolution
`proxy_pass` with static hostnames resolves DNS once at startup. If an upstream container restarts with a new IP, nginx breaks. Current fix: use `set $var hostname; proxy_pass http://$var:port;` to force per-request DNS resolution via the `resolver` directive. This is needed on Podman; may not be needed on Docker but is still good practice.

## Common Pitfalls

- **OAuth2-Proxy startup race:** oauth2-proxy depends on Keycloak being fully ready (OIDC discovery endpoint). `restart: unless-stopped` handles this via retries. On Docker, use healthcheck + `condition: service_healthy` instead.
- **PgBouncer pool mode:** Session pooling with `server_reset_query = DISCARD ALL` is required for prepared statement support. Transaction pooling breaks prepared statements.
- **Keycloak connects directly to PostgreSQL** (not through PgBouncer) because it uses JDBC.
- **Podman vs Docker on macOS:** Podman on macOS lacks `host-gateway` support, Docker embedded DNS (`127.0.0.11`), and `condition: service_healthy`. Linux or Docker Desktop avoids these issues.
- **Network name:** Compose project name `tav` + network name `tav` = `tav_tav` as the actual network name.
