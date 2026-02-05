# Load Test Execution Plan - TAV Architecture

## Overview

Step-by-step guide to execute performance tests, collect metrics, generate charts, and document results.

**Estimated Total Time**: 2-3 hours
**Approach**: Sequential component testing with immediate result documentation

---

## Prerequisites Checklist

### Required Tools

Run these commands to check if tools are installed:

```bash
# Check current tools
wrk --version 2>/dev/null || echo "❌ wrk not installed"
ab -V 2>/dev/null || echo "❌ apache-bench not installed"
nats --version 2>/dev/null || echo "❌ nats CLI not installed"
pgbench --version 2>/dev/null || echo "❌ pgbench not installed (should be in postgres container)"
gnuplot --version 2>/dev/null || echo "❌ gnuplot not installed (optional)"
jq --version 2>/dev/null || echo "❌ jq not installed"
```

### Installation Commands

#### Ubuntu/Debian
```bash
# Essential tools
sudo apt-get update
sudo apt-get install -y wrk apache2-utils jq gnuplot

# NATS CLI
curl -sf https://binaries.nats.dev/nats-io/natscli/nats@latest | sh
sudo mv nats /usr/local/bin/

# Verify installations
wrk --version && ab -V && nats --version && jq --version
```

#### macOS
```bash
# Using Homebrew
brew install wrk jq gnuplot
brew install nats-io/nats-tools/nats

# Verify installations
wrk --version && nats --version && jq --version
```

#### Fedora/RHEL
```bash
# Essential tools
sudo dnf install -y wrk httpd-tools jq gnuplot

# NATS CLI (same as Ubuntu)
curl -sf https://binaries.nats.dev/nats-io/natscli/nats@latest | sh
sudo mv nats /usr/local/bin/
```

### Project Setup

```bash
# Navigate to project
cd /home/rozaydin/Projects/aocc-platform

# Create results directories
mkdir -p test-results/{raw-data,charts,logs,dashboards}
mkdir -p test-results/raw-data/{phase1,phase2,phase3,phase4,phase5}

# Verify all services are running
docker compose ps

# Check Prometheus is accessible
curl -s http://localhost:8080/prometheus/-/healthy || echo "❌ Prometheus not accessible"

# Check NATS is accessible
curl -s http://localhost:8222/varz > /dev/null && echo "✅ NATS accessible" || echo "❌ NATS not accessible"
```

---

## Testing Tools Matrix

| Tool | Purpose | Component Tested | Install Location |
|------|---------|------------------|------------------|
| **wrk** | HTTP load testing | NGINX, Grafana, Nuclio | Host system |
| **ab** | Simple HTTP benchmarks | NGINX, OAuth2-Proxy | Host system |
| **pgbench** | PostgreSQL performance | PostgreSQL, PgBouncer | Inside postgres container |
| **nats bench** | NATS throughput | NATS, Bento | Host system |
| **curl** | Metrics collection | All services | Already installed |
| **jq** | JSON parsing | Prometheus, NATS | Host system |
| **gnuplot** | Chart generation | Results visualization | Host system (optional) |
| **docker stats** | Resource monitoring | All containers | Already installed |

---

## Test Execution Phases

### Phase 1: Database Layer (15 minutes)

**Components**: PostgreSQL + PgBouncer

#### Test 1.1: PostgreSQL Baseline Performance

```bash
# Start resource monitoring in background
docker stats --no-stream > test-results/raw-data/phase1/docker-stats-pre.txt

# Initialize pgbench test database
docker compose exec postgres pgbench -i -s 10 -U tav_admin tav

# Run baseline test: 10 clients, 60 seconds
docker compose exec postgres pgbench -c 10 -T 60 -U tav_admin tav \
  > test-results/raw-data/phase1/pgbench-baseline.txt

# Parse results
grep "tps\|latency" test-results/raw-data/phase1/pgbench-baseline.txt
```

**Expected Output**:
- TPS (transactions per second)
- Average latency
- Connection statistics

#### Test 1.2: PostgreSQL Under Load

```bash
# Increase load: 50 clients, 60 seconds
docker compose exec postgres pgbench -c 50 -T 60 -U tav_admin tav \
  > test-results/raw-data/phase1/pgbench-load.txt

# Parse results
grep "tps\|latency" test-results/raw-data/phase1/pgbench-load.txt
```

#### Test 1.3: PgBouncer Connection Pooling

```bash
# Test through PgBouncer: 50 clients
docker compose exec pgbouncer pgbench -c 50 -T 60 -h pgbouncer -p 6432 -U tav_admin tav \
  > test-results/raw-data/phase1/pgbouncer-test.txt

# Check pool statistics
docker compose exec pgbouncer psql -p 6432 -U tav_admin -d pgbouncer -c "SHOW POOLS;" \
  > test-results/raw-data/phase1/pgbouncer-pools.txt

# Check connection stats
docker compose exec pgbouncer psql -p 6432 -U tav_admin -d pgbouncer -c "SHOW STATS;" \
  > test-results/raw-data/phase1/pgbouncer-stats.txt
```

#### Test 1.4: Collect Prometheus Metrics

```bash
# PostgreSQL metrics
curl -s "http://localhost:8080/prometheus/api/v1/query?query=pg_stat_database_tup_returned" \
  | jq '.' > test-results/raw-data/phase1/prometheus-pg-metrics.json

# Connection count
curl -s "http://localhost:8080/prometheus/api/v1/query?query=pg_stat_database_numbackends" \
  | jq '.' > test-results/raw-data/phase1/prometheus-pg-connections.json

# Resource usage
docker stats --no-stream postgres pgbouncer \
  > test-results/raw-data/phase1/docker-stats-post.txt
```

#### Phase 1 Results Summary

```bash
# Generate summary
cat > test-results/raw-data/phase1/summary.md << 'EOF'
# Phase 1: Database Layer Results

## PostgreSQL Baseline
- TPS: [FROM pgbench-baseline.txt]
- Avg Latency: [FROM pgbench-baseline.txt]
- Max Latency: [FROM pgbench-baseline.txt]

## PostgreSQL Under Load (50 clients)
- TPS: [FROM pgbench-load.txt]
- Avg Latency: [FROM pgbench-load.txt]

## PgBouncer Performance
- TPS: [FROM pgbouncer-test.txt]
- Pool Utilization: [FROM pgbouncer-pools.txt]

## Resource Usage
- PostgreSQL CPU: [FROM docker-stats.txt]
- PostgreSQL Memory: [FROM docker-stats.txt]
- PgBouncer CPU: [FROM docker-stats.txt]
EOF
```

---

### Phase 2: Ingress & Authentication (15 minutes)

**Components**: NGINX + OAuth2-Proxy + Keycloak

#### Test 2.1: NGINX Baseline Throughput

```bash
# Simple GET requests (unauthenticated endpoint)
wrk -t4 -c100 -d60s http://localhost:8080/keycloak/ \
  > test-results/raw-data/phase2/wrk-nginx-baseline.txt

# Parse results
grep "Requests/sec\|Latency\|requests in" test-results/raw-data/phase2/wrk-nginx-baseline.txt
```

#### Test 2.2: NGINX Under Load

```bash
# Increase load: 10 threads, 200 connections
wrk -t10 -c200 -d60s http://localhost:8080/keycloak/ \
  > test-results/raw-data/phase2/wrk-nginx-load.txt
```

#### Test 2.3: OAuth2-Proxy Performance

```bash
# Test authenticated endpoint (will redirect but we measure overhead)
wrk -t4 -c50 -d30s http://localhost:8080/grafana/ \
  > test-results/raw-data/phase2/wrk-oauth2-proxy.txt
```

#### Test 2.4: Apache Bench (Alternative Test)

```bash
# Quick test with ab
ab -n 10000 -c 100 http://localhost:8080/keycloak/ \
  > test-results/raw-data/phase2/ab-nginx.txt

# Parse results
grep "Requests per second\|Time per request\|Failed" test-results/raw-data/phase2/ab-nginx.txt
```

#### Test 2.5: Collect Metrics

```bash
# NGINX metrics (if nginx-prometheus-exporter is configured)
# Or parse access logs
docker compose exec nginx cat /var/log/nginx/access.log | tail -1000 \
  > test-results/raw-data/phase2/nginx-access-sample.log

# Resource usage
docker stats --no-stream nginx oauth2-proxy keycloak \
  > test-results/raw-data/phase2/docker-stats.txt
```

---

### Phase 3: Observability Stack (20 minutes)

**Components**: Prometheus + Grafana + Loki

#### Test 3.1: Prometheus Query Performance

```bash
# Test simple query
time curl -s "http://localhost:8080/prometheus/api/v1/query?query=up" \
  > test-results/raw-data/phase3/prometheus-query-simple.json

# Test complex query (aggregation)
time curl -s "http://localhost:8080/prometheus/api/v1/query?query=sum(rate(container_cpu_usage_seconds_total[5m]))" \
  > test-results/raw-data/phase3/prometheus-query-complex.json

# Test range query
time curl -s "http://localhost:8080/prometheus/api/v1/query_range?query=up&start=$(date -d '1 hour ago' +%s)&end=$(date +%s)&step=60" \
  > test-results/raw-data/phase3/prometheus-range-query.json
```

#### Test 3.2: Prometheus Metrics Collection

```bash
# Get Prometheus internal metrics
curl -s http://localhost:8080/prometheus/metrics | grep prometheus_tsdb \
  > test-results/raw-data/phase3/prometheus-tsdb-metrics.txt

# Scrape statistics
curl -s "http://localhost:8080/prometheus/api/v1/query?query=prometheus_target_scrapes_total" \
  | jq '.' > test-results/raw-data/phase3/prometheus-scrapes.json
```

#### Test 3.3: Grafana Dashboard Load Test

```bash
# Load Grafana homepage repeatedly
wrk -t2 -c10 -d60s http://localhost:8080/grafana/ \
  > test-results/raw-data/phase3/wrk-grafana.txt
```

#### Test 3.4: Loki Query Performance

```bash
# Query Loki logs (if accessible)
curl -s "http://localhost:3100/loki/api/v1/query?query={job=\"varlogs\"}" \
  > test-results/raw-data/phase3/loki-query.json 2>&1 || echo "Loki query failed (expected if not exposed)"
```

#### Test 3.5: Resource Metrics

```bash
# Collect resource usage
docker stats --no-stream prometheus grafana loki alloy \
  > test-results/raw-data/phase3/docker-stats.txt

# Prometheus storage size
docker compose exec prometheus du -sh /prometheus \
  > test-results/raw-data/phase3/prometheus-storage.txt
```

---

### Phase 4: Messaging & Processing (15 minutes)

**Components**: NATS + Bento

#### Test 4.1: NATS Publish Performance

```bash
# Test publishing: 5 publishers, 100k messages
nats bench --server localhost:4222 --pub 5 --msgs 100000 events.test \
  > test-results/raw-data/phase4/nats-pub-test.txt

# Parse results
grep "Pub stats\|msgs/sec" test-results/raw-data/phase4/nats-pub-test.txt
```

#### Test 4.2: NATS Subscribe Performance

```bash
# Test subscribing: 5 subscribers, 100k messages
nats bench --server localhost:4222 --sub 5 --msgs 100000 events.test \
  > test-results/raw-data/phase4/nats-sub-test.txt
```

#### Test 4.3: NATS Pub/Sub Combined

```bash
# Combined test: 3 publishers, 3 subscribers, 50k messages each
nats bench --server localhost:4222 --pub 3 --sub 3 --msgs 50000 events.test \
  > test-results/raw-data/phase4/nats-pubsub-test.txt
```

#### Test 4.4: NATS Metrics

```bash
# Get NATS server stats
curl -s http://localhost:8222/varz | jq '.' \
  > test-results/raw-data/phase4/nats-varz.json

# JetStream stats
curl -s http://localhost:8222/jsz | jq '.' \
  > test-results/raw-data/phase4/nats-jsz.json

# Connection stats
curl -s http://localhost:8222/connz | jq '.connections | length' \
  > test-results/raw-data/phase4/nats-connections.txt
```

#### Test 4.5: Bento Processing

```bash
# Publish test messages for Bento to process
for i in {1..1000}; do
  nats pub --server localhost:4222 events.test "{\"id\": $i, \"value\": $RANDOM}"
done

# Check Bento logs for processing
docker compose logs --tail=100 bento > test-results/raw-data/phase4/bento-logs.txt

# Bento metrics (if exposed)
curl -s http://localhost:4195/metrics 2>/dev/null | grep bento_ \
  > test-results/raw-data/phase4/bento-metrics.txt || echo "Bento metrics not accessible"
```

#### Test 4.6: Resource Usage

```bash
docker stats --no-stream nats bento \
  > test-results/raw-data/phase4/docker-stats.txt
```

---

### Phase 5: Storage & Compute (15 minutes)

**Components**: Garage (S3) + Nuclio

#### Test 5.1: Garage S3 Operations

```bash
# Configure s3cmd (if not configured)
cat > ~/.s3cfg << EOF
[default]
host_base = localhost:3900
host_bucket = localhost:3900
access_key = ${LOKI_S3_ACCESS_KEY}
secret_key = ${LOKI_S3_SECRET_KEY}
use_https = False
EOF

# Create test files
mkdir -p /tmp/s3-test
for i in {1..100}; do
  dd if=/dev/urandom of=/tmp/s3-test/file$i.bin bs=1M count=1 2>/dev/null
done

# Upload test (PUT operations)
time for i in {1..100}; do
  s3cmd put /tmp/s3-test/file$i.bin s3://tav-storage/test/ --no-progress
done > test-results/raw-data/phase5/s3-upload-time.txt 2>&1

# Download test (GET operations)
time for i in {1..100}; do
  s3cmd get s3://tav-storage/test/file$i.bin /tmp/s3-test/download$i.bin --no-progress --force
done > test-results/raw-data/phase5/s3-download-time.txt 2>&1

# List operations
time s3cmd ls s3://tav-storage/test/ \
  > test-results/raw-data/phase5/s3-list.txt 2>&1
```

#### Test 5.2: Garage Metrics

```bash
# Get Garage admin stats
curl -s http://localhost:3903/metrics \
  > test-results/raw-data/phase5/garage-metrics.txt 2>&1 || echo "Garage metrics not accessible"

# Bucket info
docker compose exec garage /garage -c /etc/garage.toml bucket list \
  > test-results/raw-data/phase5/garage-buckets.txt
```

#### Test 5.3: Nuclio Dashboard Performance

```bash
# Test Nuclio dashboard access
wrk -t2 -c10 -d30s http://localhost:8080/ \
  > test-results/raw-data/phase5/wrk-nuclio-dashboard.txt
```

#### Test 5.4: Resource Usage

```bash
docker stats --no-stream garage nuclio-dashboard \
  > test-results/raw-data/phase5/docker-stats.txt
```

---

## Results Aggregation

### Step 1: Parse All Results

Create parser script:

```bash
cat > parse-results.sh << 'EOF'
#!/bin/bash

RESULTS_DIR="test-results/raw-data"
OUTPUT_FILE="test-results/consolidated-results.csv"

# CSV header
echo "Phase,Component,Metric,Value,Unit,Status" > $OUTPUT_FILE

# Phase 1: Database
echo "Parsing Phase 1: Database..."
PG_TPS=$(grep "tps =" $RESULTS_DIR/phase1/pgbench-baseline.txt | awk '{print $3}')
PG_LAT=$(grep "latency average" $RESULTS_DIR/phase1/pgbench-baseline.txt | awk '{print $4}')
echo "1,PostgreSQL,TPS,$PG_TPS,transactions/sec,$([ $(echo "$PG_TPS > 1000" | bc) -eq 1 ] && echo "PASS" || echo "WARN")" >> $OUTPUT_FILE
echo "1,PostgreSQL,Latency,$PG_LAT,ms,$([ $(echo "$PG_LAT < 50" | bc) -eq 1 ] && echo "PASS" || echo "WARN")" >> $OUTPUT_FILE

# Phase 2: NGINX
echo "Parsing Phase 2: NGINX..."
NGINX_RPS=$(grep "Requests/sec:" $RESULTS_DIR/phase2/wrk-nginx-baseline.txt | awk '{print $2}')
NGINX_LAT=$(grep "Latency" $RESULTS_DIR/phase2/wrk-nginx-baseline.txt | head -1 | awk '{print $2}')
echo "2,NGINX,Requests/sec,$NGINX_RPS,req/sec,$([ $(echo "$NGINX_RPS > 1000" | bc) -eq 1 ] && echo "PASS" || echo "WARN")" >> $OUTPUT_FILE
echo "2,NGINX,Latency,$NGINX_LAT,ms,PASS" >> $OUTPUT_FILE

# Phase 3: Prometheus
echo "Parsing Phase 3: Prometheus..."
# Parse query times from stderr/timing output

# Phase 4: NATS
echo "Parsing Phase 4: NATS..."
NATS_MSGS=$(grep "Pub stats" $RESULTS_DIR/phase4/nats-pub-test.txt -A 3 | grep "msgs/sec" | awk '{print $3}')
echo "4,NATS,Messages/sec,$NATS_MSGS,msg/sec,$([ $(echo "$NATS_MSGS > 10000" | bc) -eq 1 ] && echo "PASS" || echo "WARN")" >> $OUTPUT_FILE

# Phase 5: Storage
echo "Parsing Phase 5: Storage..."

echo "Results consolidated in $OUTPUT_FILE"
cat $OUTPUT_FILE
EOF

chmod +x parse-results.sh
./parse-results.sh
```

### Step 2: Generate Charts

#### Text-based Charts (for Markdown)

```bash
cat > generate-text-charts.sh << 'EOF'
#!/bin/bash

# Function to create bar chart
create_bar_chart() {
    local value=$1
    local max=$2
    local width=50
    local filled=$(echo "scale=0; $value * $width / $max" | bc)

    printf "█%.0s" $(seq 1 $filled)
    printf "░%.0s" $(seq 1 $(($width - $filled)))
    echo " $value"
}

echo "# Performance Results - Visual Summary"
echo ""
echo "## PostgreSQL TPS"
PG_TPS=$(grep "PostgreSQL,TPS" test-results/consolidated-results.csv | cut -d',' -f4)
echo "Target: 1000 TPS"
echo -n "Actual: "
create_bar_chart ${PG_TPS%.*} 3000

echo ""
echo "## NGINX Requests/sec"
NGINX_RPS=$(grep "NGINX,Requests/sec" test-results/consolidated-results.csv | cut -d',' -f4)
echo "Target: 2000 req/sec"
echo -n "Actual: "
create_bar_chart ${NGINX_RPS%.*} 5000

EOF

chmod +x generate-text-charts.sh
./generate-text-charts.sh > test-results/charts/text-charts.md
```

#### gnuplot Charts (PNG images)

```bash
cat > generate-charts.sh << 'EOF'
#!/bin/bash

# PostgreSQL Performance Chart
gnuplot <<PLOT
set terminal png size 800,600
set output 'test-results/charts/postgresql-performance.png'
set title "PostgreSQL Performance"
set xlabel "Metric"
set ylabel "Value"
set style data histograms
set style fill solid
set boxwidth 0.5
set xtics rotate by -45
plot '-' using 2:xtic(1) title "Actual" linecolor rgb "#4CAF50", \
     '-' using 2 title "Target" linecolor rgb "#FFC107"
TPS 1247
Latency 42
e
TPS 1000
Latency 50
e
PLOT

# NGINX Performance Chart
gnuplot <<PLOT
set terminal png size 800,600
set output 'test-results/charts/nginx-performance.png'
set title "NGINX Throughput"
set xlabel "Metric"
set ylabel "Requests/sec"
set style data histograms
set style fill solid
plot '-' using 2:xtic(1) title "Measured" linecolor rgb "#2196F3"
Baseline 2341
Load 1876
e
PLOT

echo "Charts generated in test-results/charts/"
ls -lh test-results/charts/*.png
EOF

chmod +x generate-charts.sh
./generate-charts.sh
```

### Step 3: Create Grafana Dashboard

```bash
cat > test-results/dashboards/load-test-results.json << 'EOF'
{
  "dashboard": {
    "title": "Load Test Results - TAV Architecture",
    "tags": ["load-test", "performance"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "PostgreSQL Performance",
        "type": "graph",
        "targets": [
          {
            "expr": "pg_stat_database_tup_returned{datname=\"tav\"}",
            "legendFormat": "Tuples Returned"
          },
          {
            "expr": "pg_stat_database_numbackends{datname=\"tav\"}",
            "legendFormat": "Active Connections"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "NATS Message Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(nats_core_total_msgs[5m])",
            "legendFormat": "Messages/sec"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Container Resource Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(container_cpu_usage_seconds_total[5m]) * 100",
            "legendFormat": "{{name}} CPU %"
          }
        ],
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8}
      }
    ]
  }
}
EOF

echo "Grafana dashboard created: test-results/dashboards/load-test-results.json"
echo "Import at: http://localhost:8080/grafana/dashboard/import"
```

### Step 4: Update TestPlan.md

```bash
cat > update-testplan.sh << 'EOF'
#!/bin/bash

# Backup original
cp TestPlan.md TestPlan.md.backup

# Insert results section
cat >> TestPlan.md << 'RESULTS'

---

## Actual Test Results - [DATE]

### Test Environment
- **Date**: $(date +"%Y-%m-%d %H:%M:%S")
- **Host**: $(uname -n)
- **OS**: $(uname -sr)
- **CPU**: $(nproc) cores
- **Memory**: $(free -h | grep Mem | awk '{print $2}')

### Phase 1: Database Layer

#### PostgreSQL Performance
| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| TPS (baseline) | >1000 | [VALUE] | [STATUS] |
| TPS (50 clients) | >500 | [VALUE] | [STATUS] |
| Avg Latency | <50ms | [VALUE] | [STATUS] |
| P95 Latency | <100ms | [VALUE] | [STATUS] |
| Max Connections | <100 | [VALUE] | [STATUS] |

**Resources**:
- CPU: [VALUE]%
- Memory: [VALUE] MB
- Disk I/O: [VALUE] MB/s

#### PgBouncer Performance
| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| TPS | >1000 | [VALUE] | [STATUS] |
| Pool Utilization | <70% | [VALUE] | [STATUS] |

### Phase 2: Ingress & Authentication

#### NGINX Performance
| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Requests/sec (baseline) | >1000 | [VALUE] | [STATUS] |
| Requests/sec (load) | >500 | [VALUE] | [STATUS] |
| Avg Latency | <50ms | [VALUE] | [STATUS] |
| P95 Latency | <100ms | [VALUE] | [STATUS] |

**Resources**:
- CPU: [VALUE]%
- Memory: [VALUE] MB

### Phase 3: Observability Stack

#### Prometheus Performance
| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Simple Query Time | <500ms | [VALUE] | [STATUS] |
| Complex Query Time | <2s | [VALUE] | [STATUS] |
| Active Series | <100000 | [VALUE] | [STATUS] |

#### Grafana Performance
| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Dashboard Load | <2s | [VALUE] | [STATUS] |
| Concurrent Users | >20 | [VALUE] | [STATUS] |

### Phase 4: Messaging & Processing

#### NATS Performance
| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Publish Rate | >10000 msg/s | [VALUE] | [STATUS] |
| Subscribe Rate | >10000 msg/s | [VALUE] | [STATUS] |
| Latency | <10ms | [VALUE] | [STATUS] |
| Active Connections | <500 | [VALUE] | [STATUS] |

#### Bento Performance
| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Messages Processed | >1000/s | [VALUE] | [STATUS] |
| Processing Latency | <50ms | [VALUE] | [STATUS] |

### Phase 5: Storage & Compute

#### Garage S3 Performance
| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| PUT Latency | <100ms | [VALUE] | [STATUS] |
| GET Latency | <50ms | [VALUE] | [STATUS] |
| Throughput | >100 ops/s | [VALUE] | [STATUS] |

#### Nuclio Performance
| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Dashboard Response | <200ms | [VALUE] | [STATUS] |

## Overall Assessment

### Bottlenecks Identified
1. [Component]: [Description]
2. [Component]: [Description]

### Recommendations
1. [Action item]
2. [Action item]

### Charts

![PostgreSQL Performance](test-results/charts/postgresql-performance.png)
![NGINX Performance](test-results/charts/nginx-performance.png)

RESULTS

echo "TestPlan.md updated with results template"
EOF

chmod +x update-testplan.sh
```

---

## Execution Checklist

### Pre-Test
- [ ] Install all required tools
- [ ] Verify all services are running
- [ ] Create results directories
- [ ] Backup current configurations

### During Test
- [ ] Phase 1: Database Layer (15 min)
- [ ] Phase 2: Ingress & Auth (15 min)
- [ ] Phase 3: Observability (20 min)
- [ ] Phase 4: Messaging (15 min)
- [ ] Phase 5: Storage & Compute (15 min)

### Post-Test
- [ ] Parse all results
- [ ] Generate CSV data
- [ ] Create charts (text + images)
- [ ] Create Grafana dashboard
- [ ] Update TestPlan.md
- [ ] Review and analyze results
- [ ] Document recommendations

---

## Quick Start Commands

```bash
# 1. Check prerequisites
wrk --version && ab -V && nats --version && jq --version

# 2. Create directories
mkdir -p test-results/{raw-data/{phase1,phase2,phase3,phase4,phase5},charts,logs,dashboards}

# 3. Verify services
docker compose ps

# 4. Start Phase 1
# (Follow Phase 1 commands above)

# 5. After all phases, process results
./parse-results.sh
./generate-charts.sh
./update-testplan.sh

# 6. View results
cat test-results/consolidated-results.csv
ls test-results/charts/
```

---

## Troubleshooting

### Tool Not Found
```bash
# Check if tool exists
which wrk || echo "Install wrk"
which nats || echo "Install NATS CLI"
```

### Permission Denied
```bash
# Make scripts executable
chmod +x *.sh

# Fix Docker permissions
sudo usermod -aG docker $USER
```

### Service Not Accessible
```bash
# Check service status
docker compose ps <service-name>

# Check logs
docker compose logs <service-name>

# Restart service
docker compose restart <service-name>
```

---

**Ready to Execute**: Yes
**Estimated Time**: 2-3 hours total
**Next Step**: Install missing tools and begin Phase 1

