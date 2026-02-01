# TAV Architecture Platform

A comprehensive, self-hosted infrastructure platform combining monitoring, logging, serverless computing, object storage, and stream processing capabilities.

## Architecture Overview

TAV Architecture is a modern, cloud-native infrastructure stack built on Docker Compose, designed for observability, event-driven processing, and serverless workloads. All services are protected by OAuth2-Proxy with Keycloak authentication.

### Core Components

**Data & Storage**
- **PostgreSQL**: Primary relational database
- **PgBouncer**: Connection pooler for efficient database access
- **Garage**: S3-compatible object storage for backups and artifacts

**Authentication & Security**
- **Keycloak**: Identity and access management (OIDC provider)
- **OAuth2-Proxy**: Single sign-on proxy for all services
- **NGINX**: Reverse proxy and ingress gateway

**Monitoring & Observability**
- **Grafana**: Dashboards and visualization
- **Prometheus**: Metrics collection and time-series database
- **Alertmanager**: Alert management and routing
- **Loki**: Log aggregation system
- **Alloy**: Telemetry collector (logs, metrics, traces)
- **cAdvisor**: Container resource monitoring
- **Postgres Exporter**: PostgreSQL metrics

**Compute & Processing**
- **Nuclio**: Serverless function platform (FaaS)
- **NATS**: High-performance message broker with JetStream
- **Bento**: Stream processor for ETL pipelines

## Prerequisites

- **Docker** 20.10+ or **Podman** 4.0+
- **Docker Compose** 2.0+ or **podman-compose**
- **Linux** (recommended) or macOS/Windows with Docker Desktop
- **Minimum Resources**: 8GB RAM, 20GB disk space
- **Ports**: 8080 (HTTP), 4222 (NATS), 8222 (NATS monitoring)

## Quick Start

### 1. Clone and Setup

```bash
# Clone the repository
git clone <repository-url>
cd aocc-platform

# Review and update credentials in .env
cp .env.example .env  # If example exists
nano .env  # Update passwords and secrets
```

### 2. Initialize Garage Storage

Start Garage first to create storage buckets:

```bash
# Start Garage
docker compose up -d postgres garage

# Wait for services to be ready
sleep 10

# Create cluster layout (single node)
docker compose exec garage /garage -c /etc/garage.toml \
  layout assign $(docker compose exec garage /garage -c /etc/garage.toml node id -q) \
  -c 1 -z dc1 -t node1

docker compose exec garage /garage -c /etc/garage.toml layout apply --version 1

# Create storage buckets and access keys
docker compose exec garage /garage -c /etc/garage.toml bucket create tav-storage
docker compose exec garage /garage -c /etc/garage.toml bucket create loki-chunks
docker compose exec garage /garage -c /etc/garage.toml bucket create nuclio-artifacts

# Create access keys for Loki
docker compose exec garage /garage -c /etc/garage.toml key create loki-key
# Save the Access Key ID and Secret Key, update .env:
# LOKI_S3_ACCESS_KEY=<Access Key ID>
# LOKI_S3_SECRET_KEY=<Secret Key>

# Grant permissions to Loki
docker compose exec garage /garage -c /etc/garage.toml bucket allow \
  --read --write loki-chunks --key loki-key

# Create access keys for Nuclio
docker compose exec garage /garage -c /etc/garage.toml key create nuclio-key
# Save the Access Key ID and Secret Key, update .env:
# NUCLIO_S3_ACCESS_KEY=<Access Key ID>
# NUCLIO_S3_SECRET_KEY=<Secret Key>

# Grant permissions to Nuclio
docker compose exec garage /garage -c /etc/garage.toml bucket allow \
  --read --write nuclio-artifacts --key nuclio-key
```

### 3. Configure Keycloak

```bash
# Start Keycloak
docker compose up -d keycloak

# Wait for Keycloak to be ready (check logs)
docker compose logs -f keycloak
# Wait until you see "Admin console listening"

# Access Keycloak admin console
open http://localhost:8080/keycloak/

# Login with admin credentials from .env
# KEYCLOAK_ADMIN=admin
# KEYCLOAK_ADMIN_PASSWORD=<your-password>

# Create realm 'tav':
# 1. Click "Create Realm"
# 2. Realm name: tav
# 3. Click "Create"

# Create client 'grafana':
# 1. Go to Clients → Create client
# 2. Client ID: grafana
# 3. Client type: OpenID Connect
# 4. Click "Next"
# 5. Client authentication: ON
# 6. Valid redirect URIs: http://localhost:8080/oauth2/callback
# 7. Web origins: http://localhost:8080
# 8. Click "Save"

# Get client secret:
# 1. Go to Clients → grafana → Credentials tab
# 2. Copy "Client secret"
# 3. Update .env: OAUTH2_PROXY_CLIENT_SECRET=<client-secret>

# Create test user:
# 1. Go to Users → Add user
# 2. Username: testuser
# 3. Email: test@example.com
# 4. Email verified: ON
# 5. Click "Create"
# 6. Go to Credentials tab → Set password
# 7. Password: <choose-password>
# 8. Temporary: OFF
```

### 4. Start All Services

```bash
# Update .env with Garage keys and Keycloak client secret
nano .env

# Start the full stack
docker compose up -d

# Verify all services are running
docker compose ps

# Check logs for any errors
docker compose logs -f
```

### 5. Access the Platform

Navigate to http://localhost:8080/ - you'll be redirected to Keycloak for authentication.

Login with the user created in Step 3.

## Service Endpoints

All services are protected by OAuth2-Proxy and require Keycloak authentication, except where noted.

### Public Endpoints

| Service | URL | Description |
|---------|-----|-------------|
| **Nuclio Dashboard** | http://localhost:8080/ | Serverless function management (root path) |
| **Grafana** | http://localhost:8080/grafana/ | Monitoring dashboards and visualization |
| **Prometheus** | http://localhost:8080/prometheus/ | Metrics and alerting rules |
| **Alertmanager** | http://localhost:8080/alertmanager/ | Alert management UI |
| **Keycloak** | http://localhost:8080/keycloak/ | Identity management console |
| **OAuth2 Logout** | http://localhost:8080/oauth2/sign_out | Logout from all services |

### Internal Endpoints (Container Network)

| Service | Internal URL | Port | Description |
|---------|--------------|------|-------------|
| **PostgreSQL** | postgres:5432 | 5432 | Primary database |
| **PgBouncer** | pgbouncer:6432 | 6432 | Database connection pool |
| **NATS** | nats:4222 | 4222 | Message broker (client) |
| **NATS Monitoring** | nats:8222 | 8222 | NATS metrics endpoint |
| **Bento Metrics** | bento:4195 | 4195 | Bento metrics endpoint |
| **Garage S3 API** | garage:3900 | 3900 | S3-compatible API |
| **Garage Admin** | garage:3903 | 3903 | Admin API |
| **Loki** | loki:3100 | 3100 | Log query API |

### Direct Access Endpoints

These ports are exposed to the host:

| Port | Service | Description |
|------|---------|-------------|
| 8080 | NGINX | Main HTTP ingress |
| 4222 | NATS | Message broker (for external clients) |
| 8222 | NATS | Monitoring/metrics |

## Configuration Files

### Critical Configuration Files

```
.
├── .env                          # Environment variables and secrets
├── compose.yml                   # Docker Compose service definitions
├── nginx/
│   └── nginx.conf               # Reverse proxy and routing configuration
├── postgres/
│   └── init.sql                 # Database initialization
├── pgbouncer/
│   ├── pgbouncer.ini           # Connection pool settings
│   └── entrypoint.sh           # User authentication setup
├── prometheus/
│   ├── prometheus.yml          # Metrics scraping configuration
│   └── alert-rules.yml         # Alerting rules
├── loki/
│   └── loki.yaml               # Log aggregation configuration
├── nats/
│   └── nats.conf               # NATS server configuration
├── bento/
│   └── bento.yaml              # Stream processing pipeline
└── grafana/
    └── provisioning/            # Grafana datasources and dashboards
```

## Common Operations

### Starting and Stopping Services

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart specific service
docker compose restart <service-name>

# View logs
docker compose logs -f <service-name>

# Check service status
docker compose ps
```

### Database Operations

```bash
# Connect to PostgreSQL
docker compose exec pgbouncer psql -U tav_admin -d tav

# List databases
docker compose exec pgbouncer psql -U tav_admin -d postgres -c "\l"

# Run SQL query
docker compose exec pgbouncer psql -U tav_admin -d tav -c "SELECT version();"
```

### Garage Storage Operations

```bash
# List buckets
docker compose exec garage /garage -c /etc/garage.toml bucket list

# Bucket info
docker compose exec garage /garage -c /etc/garage.toml bucket info <bucket-name>

# List keys
docker compose exec garage /garage -c /etc/garage.toml key list

# Key info
docker compose exec garage /garage -c /etc/garage.toml key info <key-name>
```

### NATS Operations

Requires NATS CLI installed on host:

```bash
# Install NATS CLI
# Linux:
curl -sf https://binaries.nats.dev/nats-io/natscli/nats@latest | sh

# macOS:
brew install nats-io/nats-tools/nats

# Publish message
nats pub -s localhost:4222 events.test '{"message": "Hello!"}'

# Subscribe to messages
nats sub -s localhost:4222 "events.>"

# View NATS info
curl http://localhost:8222/varz | jq

# JetStream status
curl http://localhost:8222/jsz | jq
```

### Monitoring and Logs

```bash
# View Prometheus targets
open http://localhost:8080/prometheus/targets

# Query logs in Loki (via Grafana)
open http://localhost:8080/grafana/explore

# View container metrics
open http://localhost:8080/grafana/

# Check Alertmanager
open http://localhost:8080/alertmanager/
```

## Nuclio Functions

### Deploying Functions

1. **Access Nuclio Dashboard**: http://localhost:8080/
2. **Create Project**: Click "New Project" → Name: "my-project"
3. **Create Function**: Click "Create function" → Choose runtime
4. **Configure Function**:
   ```yaml
   spec:
     runtime: "python:3.9"
     handler: "main:handler"

     env:
       - name: POSTGRES_USER
         value: "tav_admin"
       - name: POSTGRES_PASSWORD
         value: "your-password"

     build:
       commands:
         - pip install requests psycopg2-binary

     platform:
       attributes:
         network: tav_tav
   ```
5. **Deploy**: Click "Deploy"

### Example Function

```python
import json

def handler(context, event):
    """Example Nuclio function"""
    context.logger.info(f"Received: {event.method} {event.path}")

    response = {
        "message": "Hello from Nuclio!",
        "body": event.body.decode('utf-8') if event.body else None
    }

    return context.Response(
        body=json.dumps(response),
        headers={'Content-Type': 'application/json'},
        status_code=200
    )
```

### Function with NATS Integration

```python
import nats
import json
import asyncio

async def handler(context, event):
    """Publish to NATS"""
    nc = await nats.connect("nats://nats:4222")

    message = {
        "event": "user.action",
        "data": event.body.decode('utf-8') if event.body else None
    }

    await nc.publish("events.user", json.dumps(message).encode())
    await nc.close()

    return context.Response(
        body=json.dumps({"status": "published"}),
        status_code=200
    )
```

### Exposing Functions via NGINX

After deploying a function, add route to `nginx/nginx.conf`:

```nginx
# ---------- Nuclio Function: my-function ----------
location /functions/my-function/ {
    proxy_pass http://nuclio-my-function:8080/;
    proxy_set_header Host                    $http_host;
    proxy_set_header X-Real-IP               $remote_addr;
    proxy_set_header X-Forwarded-For          $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto        $scheme;
}
```

Reload NGINX:
```bash
docker compose exec nginx nginx -s reload
```

## Bento Stream Processing

### Current Pipeline

The default Bento configuration (`bento/bento.yaml`) demonstrates:
- **Input**: Subscribe to NATS subject `events.>`
- **Processing**: Add timestamp, parse JSON, enrich data
- **Output**: Log to stdout

### Viewing Processed Messages

```bash
# View Bento logs
docker compose logs -f bento

# Publish test message to NATS
nats pub -s localhost:4222 events.test '{"user": "john", "action": "login"}'

# See processed output in Bento logs
```

### Custom Pipelines

Edit `bento/bento.yaml` for custom processing:

```yaml
input:
  nats:
    urls: ["nats://nats:4222"]
    subject: "events.>"

pipeline:
  processors:
    - bloblang: |
        root = this
        root.timestamp = now().format("2006-01-02T15:04:05Z")

output:
  stdout:
    codec: lines
```

Restart Bento:
```bash
docker compose restart bento
```

## Architecture Patterns

### Event-Driven Processing

```
Nuclio Function → NATS → Bento → PostgreSQL/S3
```

1. Nuclio function publishes event to NATS
2. Bento subscribes and processes event
3. Processed data stored in PostgreSQL or Garage S3

### Log Aggregation

```
Containers → Alloy → Loki → Grafana
```

All container logs automatically collected and queryable in Grafana.

### Metrics Collection

```
Services → Prometheus → Grafana/Alertmanager
```

Metrics from all services scraped by Prometheus every 30s.

## Security Considerations

### Authentication

- All web services protected by OAuth2-Proxy
- Keycloak provides OIDC authentication
- Session cookies encrypted with `OAUTH2_PROXY_COOKIE_SECRET`

### Database Access

- PostgreSQL credentials in `.env` (gitignored)
- PgBouncer enforces connection limits
- Separate databases for each service (tav, keycloak, grafana)

### Secrets Management

**Important**: Never commit `.env` to version control!

Rotate secrets regularly:
```bash
# Generate new OAuth2 cookie secret
openssl rand -base64 32

# Generate new RPC secret for Garage
openssl rand -hex 32
```

### Network Isolation

- Services communicate via internal Docker network `tav`
- Only NGINX exposed to host (port 8080)
- NATS optionally exposed (port 4222) for external clients

## Troubleshooting

### Service Won't Start

```bash
# Check logs
docker compose logs <service-name>

# Check dependencies
docker compose ps

# Verify configuration
docker compose config
```

### Authentication Issues

```bash
# Verify Keycloak realm and client exist
open http://localhost:8080/keycloak/

# Check OAuth2-Proxy logs
docker compose logs oauth2-proxy

# Test redirect
curl -I http://localhost:8080/
```

### Database Connection Issues

```bash
# Test PostgreSQL
docker compose exec postgres psql -U tav_admin -d tav -c "SELECT 1;"

# Test PgBouncer
docker compose exec pgbouncer psql -U tav_admin -d tav -c "SELECT 1;"

# Check connections
docker compose exec pgbouncer psql -U tav_admin -p 6432 -d pgbouncer -c "SHOW POOLS;"
```

### NATS Connection Issues

```bash
# Check NATS status
curl http://localhost:8222/varz

# Test connection
nats --server localhost:4222 rtt

# View connections
curl http://localhost:8222/connz
```

### Garage Storage Issues

```bash
# Check cluster status
docker compose exec garage /garage -c /etc/garage.toml status

# Verify layout
docker compose exec garage /garage -c /etc/garage.toml layout show
```

## Backup and Restore

### Database Backup

```bash
# Backup PostgreSQL
docker compose exec postgres pg_dump -U tav_admin tav > backup.sql

# Restore
docker compose exec -T postgres psql -U tav_admin tav < backup.sql
```

### Garage Backup

```bash
# Backup using S3 CLI (s3cmd or aws cli)
# Configure with Garage credentials from .env
s3cmd --host=localhost:3900 \
      --access_key=<LOKI_S3_ACCESS_KEY> \
      --secret_key=<LOKI_S3_SECRET_KEY> \
      sync s3://tav-storage ./backup/
```

### Configuration Backup

```bash
# Backup all configs
tar -czf config-backup.tar.gz \
  .env \
  nginx/ \
  prometheus/ \
  loki/ \
  nats/ \
  bento/ \
  grafana/provisioning/
```

## Performance Tuning

### PostgreSQL

Edit `postgres/init.sql` or use environment variables:
```yaml
POSTGRES_MAX_CONNECTIONS: 200
POSTGRES_SHARED_BUFFERS: 256MB
```

### PgBouncer

Edit `pgbouncer/pgbouncer.ini`:
```ini
default_pool_size = 25
max_client_conn = 200
```

### NATS

Edit `nats/nats.conf`:
```conf
max_connections: 2000
max_payload: 10MB
```

### Prometheus

Edit `prometheus/prometheus.yml`:
```yaml
global:
  scrape_interval: 15s  # More frequent scraping
```

## Maintenance

### Updating Services

```bash
# Pull latest images
docker compose pull

# Recreate containers
docker compose up -d

# Verify
docker compose ps
```

### Cleaning Up

```bash
# Remove unused images
docker image prune -a

# Remove unused volumes (WARNING: deletes data)
docker volume prune

# Remove everything and start fresh (WARNING: deletes ALL data)
docker compose down -v
```

## Development

### Adding New Services

1. Add service to `compose.yml`
2. Update `prometheus/prometheus.yml` if metrics available
3. Add NGINX location if web UI needed
4. Update this README

### Testing Changes

```bash
# Validate compose file
docker compose config

# Check for errors
docker compose up --dry-run

# Test single service
docker compose up <service-name>
```

## Monitoring Dashboards

### Recommended Grafana Dashboards

Import these dashboards in Grafana:

1. **NATS** (ID: 2279)
2. **PostgreSQL** (ID: 9628)
3. **Docker Containers** (ID: 179)
4. **NGINX** (ID: 462)
5. **JVM Metrics** (for Keycloak) (ID: 4701)

### Creating Custom Dashboards

1. Go to http://localhost:8080/grafana/
2. Navigate to Dashboards → New → New Dashboard
3. Add panels with Prometheus queries
4. Save dashboard

## Support and Resources

### Documentation Links

- [NATS Documentation](https://docs.nats.io/)
- [Bento Documentation](https://warpstreamlabs.github.io/bento/)
- [Nuclio Documentation](https://nuclio.io/docs/)
- [Garage Documentation](https://garagehq.deuxfleurs.fr/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Keycloak Documentation](https://www.keycloak.org/documentation)

### Service Versions

- NATS: latest (2.12.4+)
- Bento: latest (1.14.1+)
- Nuclio: stable-amd64
- PostgreSQL: latest (16+)
- Grafana: latest
- Prometheus: latest
- Loki: latest
- Keycloak: latest

## License

[Add your license information here]

## Contributors

[Add contributor information here]

---

**Version**: 1.0.0
**Last Updated**: 2026-02-01
