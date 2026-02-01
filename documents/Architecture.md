 ##  Components

### 1. [NGINX (Ingress)](https://nginx.org/)
High-performance web server and reverse proxy.  
Acts as the **ingress gateway**, routing external HTTP(S) traffic into internal services securely and efficiently.

### 2. [PostgreSQL](https://www.postgresql.org/)
Powerful open-source **relational database** known for stability, ACID compliance, and advanced SQL support.  
Serves as the main **persistent data store** for application and system data.

### 3. [PgBouncer](https://www.pgbouncer.org/)
Lightweight **connection pooler** for PostgreSQL.  
Improves database efficiency by reusing connections and managing access (e.g., enforcing read-only roles for addons).

### 4. [Postgres Exporter](https://github.com/prometheus-community/postgres_exporter)
A **Prometheus exporter** that exposes key PostgreSQL metrics like connection counts, query times, and cache hit ratios.  
Used to feed performance data into the monitoring system.

### 5. [Garage](https://garagehq.deuxfleurs.fr/)
High-performance, **S3-compatible object storage** system.  
Ideal for backups, artifacts, or ETL outputs. Can act as a local or hybrid **data lake backend**.

### 6. [NATS](https://nats.io/)
Lightweight, high-speed **message broker** supporting pub/sub and request/reply patterns.  
Forms the **event and communication backbone** between internal services via JetStream or Core NATS.

### 7. [Bento](https://warpstreamlabs.github.io/bento/)
Flexible and powerful **stream processor** for ETL and data pipelines.  
Consumes data from NATS or other sources, applies transformations, and outputs to destinations like MinIO or PostgreSQL.

### 8. [Grafana](https://grafana.com/)
Industry-standard **dashboard and visualization platform**.  
Used to visualize metrics, logs, and traces from Prometheus, Loki, and other data sources.

### 9. [Prometheus](https://prometheus.io/)
**Metrics collector** and time-series database for system and application observability.  
Scrapes metrics from exporters (e.g., Postgres Exporter, cAdvisor) and powers dashboards and alerts.

### 10. [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/)
Component of the Prometheus ecosystem that **manages alert notifications**.  
Handles alert deduplication, grouping, silencing, and routing to email, Slack, or webhook channels.

### 11. [cAdvisor](https://github.com/google/cadvisor)
Google’s **container resource monitor**.  
Exports CPU, memory, disk, and network statistics per container to Prometheus for live resource tracking.

### 12. [Grafana Loki](https://grafana.com/oss/loki/)
Scalable and cost-efficient **log aggregation system**, designed with Prometheus principles.  
Indexes labels instead of full text, making it lightweight and ideal for container logs.

### 13. [Grafana Alloy](https://grafana.com/oss/alloy/)
Modern **telemetry collector and agent** (successor to Promtail/Grafana Agent).  
Collects logs, metrics, and traces using OpenTelemetry pipelines, unifying observability data ingestion.

### 14. [Nuclio](https://nuclio.io/)
High-performance serverless computing platform for running event-driven functions over Docker or Kubernetes.
Integrates natively with NATS, HTTP, Kafka, and cron triggers, allowing functions to react to messages, webhooks, or scheduled events.
Lightweight, self-hosted, and ideal for adding Function-as-a-Service (FaaS) capability on top of your existing stack.

### 15. [Keycloak](https://www.keycloak.org/)


### 16. [OAuth2-Proxy](https://github.com/oauth2-proxy/oauth2-proxy)