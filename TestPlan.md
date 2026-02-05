# TAV Architecture - Load Testing & KPI Measurement Plan

## Executive Summary

This document defines the load testing strategy and Key Performance Indicators (KPIs) for the TAV Architecture platform. It provides methodologies for measuring performance, capacity limits, and resource utilization under various load conditions.

**Test Environment**: Docker Compose deployment on single host
**Target**: Establish baseline performance metrics and identify bottlenecks

---

## 1. Test Objectives

### Primary Goals

1. **Establish Performance Baselines**: Measure normal operation metrics
2. **Identify Bottlenecks**: Find system constraints under load
3. **Validate Scalability**: Determine maximum sustainable load
4. **Measure Resource Utilization**: CPU, memory, disk, network usage
5. **Test Failure Scenarios**: System behavior under stress
6. **Verify SLA Compliance**: Meet latency and availability targets

### Success Criteria

- ✅ All services remain stable under baseline load
- ✅ Response times stay within acceptable thresholds
- ✅ No data loss during normal operations
- ✅ Graceful degradation under extreme load
- ✅ Recovery within 5 minutes after overload

---

## 2. Key Performance Indicators (KPIs)

### 2.1 System-Wide KPIs

| KPI | Target | Warning | Critical | Measurement |
|-----|--------|---------|----------|-------------|
| **Overall Availability** | 99.9% | < 99.5% | < 99% | Prometheus `up` metric |
| **Request Success Rate** | > 99.5% | < 99% | < 95% | HTTP 2xx / total requests |
| **Mean Response Time** | < 200ms | < 500ms | > 1s | NGINX access log analysis |
| **P95 Response Time** | < 500ms | < 1s | > 2s | Prometheus histogram |
| **P99 Response Time** | < 1s | < 2s | > 5s | Prometheus histogram |
| **Error Rate** | < 0.1% | < 1% | > 5% | HTTP 5xx / total requests |

### 2.2 Component-Specific KPIs

#### PostgreSQL + PgBouncer

| KPI | Target | Warning | Critical |
|-----|--------|---------|----------|
| **Query Response Time (avg)** | < 50ms | < 100ms | > 200ms |
| **Connection Pool Utilization** | < 70% | < 85% | > 95% |
| **Active Connections** | < 100 | < 150 | > 180 |
| **Transaction Rate** | > 1000 TPS | > 500 TPS | < 100 TPS |
| **Cache Hit Ratio** | > 95% | > 90% | < 85% |
| **Disk I/O Wait** | < 10% | < 20% | > 30% |
| **Replication Lag** | < 1s | < 5s | > 10s |

**Measurement Queries**:
```sql
-- Active connections
SELECT count(*) FROM pg_stat_activity WHERE state = 'active';

-- Cache hit ratio
SELECT
  round(100.0 * sum(blks_hit) / nullif(sum(blks_hit + blks_read), 0), 2) AS cache_hit_ratio
FROM pg_stat_database;

-- Transaction rate
SELECT xact_commit + xact_rollback AS total_transactions
FROM pg_stat_database WHERE datname = 'tav';
```

#### NGINX (Ingress)

| KPI | Target | Warning | Critical |
|-----|--------|---------|----------|
| **Requests/Second** | > 1000 | > 500 | < 100 |
| **Concurrent Connections** | < 5000 | < 8000 | > 10000 |
| **Response Time (avg)** | < 50ms | < 100ms | > 200ms |
| **4xx Error Rate** | < 1% | < 5% | > 10% |
| **5xx Error Rate** | < 0.1% | < 1% | > 5% |
| **SSL/TLS Handshake Time** | < 100ms | < 200ms | > 500ms |

**Prometheus Queries**:
```promql
# Request rate
rate(nginx_http_requests_total[5m])

# Average response time
rate(nginx_http_request_duration_seconds_sum[5m]) /
rate(nginx_http_request_duration_seconds_count[5m])

# Error rate
sum(rate(nginx_http_requests_total{status=~"5.."}[5m])) /
sum(rate(nginx_http_requests_total[5m])) * 100
```

#### Keycloak + OAuth2-Proxy

| KPI | Target | Warning | Critical |
|-----|--------|---------|----------|
| **Login Response Time** | < 500ms | < 1s | > 2s |
| **Token Validation Time** | < 50ms | < 100ms | > 200ms |
| **Successful Logins/min** | > 100 | > 50 | < 10 |
| **Failed Login Rate** | < 1% | < 5% | > 10% |
| **Session Creation Rate** | > 50/min | > 20/min | < 5/min |
| **JVM Heap Usage** | < 70% | < 85% | > 95% |

#### Grafana

| KPI | Target | Warning | Critical |
|-----|--------|---------|----------|
| **Dashboard Load Time** | < 2s | < 5s | > 10s |
| **Query Response Time** | < 1s | < 3s | > 5s |
| **Concurrent Users** | > 50 | > 20 | < 10 |
| **API Response Time** | < 200ms | < 500ms | > 1s |
| **Datasource Query Rate** | > 100/s | > 50/s | < 10/s |

#### Prometheus

| KPI | Target | Warning | Critical |
|-----|--------|---------|----------|
| **Scrape Duration (avg)** | < 1s | < 3s | > 5s |
| **Samples Ingested/sec** | > 10000 | > 5000 | < 1000 |
| **Query Response Time** | < 500ms | < 2s | > 5s |
| **TSDB Size** | < 10GB | < 15GB | > 20GB |
| **Active Series** | < 100000 | < 200000 | > 500000 |
| **Scrape Failures** | < 0.1% | < 1% | > 5% |

**Prometheus Queries**:
```promql
# Scrape duration
rate(prometheus_target_scrape_duration_seconds_sum[5m]) /
rate(prometheus_target_scrape_duration_seconds_count[5m])

# Samples ingested
rate(prometheus_tsdb_head_samples_appended_total[5m])

# Query duration
rate(prometheus_engine_query_duration_seconds_sum[5m]) /
rate(prometheus_engine_query_duration_seconds_count[5m])
```

#### Loki

| KPI | Target | Warning | Critical |
|-----|--------|---------|----------|
| **Log Ingestion Rate** | > 1000 lines/s | > 500 lines/s | < 100 lines/s |
| **Query Response Time** | < 2s | < 5s | > 10s |
| **Storage Size** | < 50GB | < 80GB | > 100GB |
| **Chunk Upload Latency** | < 1s | < 3s | > 5s |
| **Failed Chunks** | 0 | < 10/min | > 50/min |

#### NATS

| KPI | Target | Warning | Critical |
|-----|--------|---------|----------|
| **Messages/Second** | > 10000 | > 5000 | < 1000 |
| **Message Latency (avg)** | < 10ms | < 50ms | > 100ms |
| **Active Connections** | < 500 | < 800 | > 1000 |
| **Subscription Count** | < 1000 | < 2000 | > 5000 |
| **JetStream Storage** | < 5GB | < 8GB | > 10GB |
| **Slow Consumers** | 0 | < 5 | > 10 |

**Metrics Endpoints**:
```bash
# NATS server stats
curl http://localhost:8222/varz | jq '.messages, .bytes, .connections'

# JetStream stats
curl http://localhost:8222/jsz | jq '.streams, .consumers'
```

#### Bento

| KPI | Target | Warning | Critical |
|-----|--------|---------|----------|
| **Messages Processed/sec** | > 1000 | > 500 | < 100 |
| **Processing Latency** | < 50ms | < 100ms | > 200ms |
| **Error Rate** | < 0.1% | < 1% | > 5% |
| **Backlog Size** | 0 | < 1000 | > 10000 |
| **Memory Usage** | < 512MB | < 768MB | > 1GB |

**Prometheus Queries**:
```promql
# Message throughput
rate(bento_input_received_total[5m])
rate(bento_output_sent_total[5m])

# Processing errors
rate(bento_processor_error_total[5m])
```

#### Nuclio

| KPI | Target | Warning | Critical |
|-----|--------|---------|----------|
| **Function Invocations/sec** | > 100 | > 50 | < 10 |
| **Function Duration (avg)** | < 100ms | < 500ms | > 1s |
| **Cold Start Time** | < 1s | < 3s | > 5s |
| **Function Errors** | < 0.1% | < 1% | > 5% |
| **Active Function Pods** | < 50 | < 80 | > 100 |

#### Garage (S3)

| KPI | Target | Warning | Critical |
|-----|--------|---------|----------|
| **PUT Requests/sec** | > 100 | > 50 | < 10 |
| **GET Requests/sec** | > 500 | > 200 | < 50 |
| **PUT Latency** | < 100ms | < 500ms | > 1s |
| **GET Latency** | < 50ms | < 100ms | > 200ms |
| **Storage Utilization** | < 70% | < 85% | > 95% |
| **Failed Requests** | < 0.1% | < 1% | > 5% |

---

## 3. Load Testing Scenarios

### Scenario 1: Baseline Load (Normal Operations)

**Duration**: 30 minutes
**Load Pattern**: Constant load representing typical usage

| Component | Load Profile |
|-----------|--------------|
| **NGINX** | 500 req/sec, 80% authenticated |
| **PostgreSQL** | 200 queries/sec |
| **NATS** | 1000 msgs/sec |
| **Nuclio** | 50 function calls/sec |
| **Grafana** | 20 concurrent users |
| **S3 (Garage)** | 50 PUT/sec, 200 GET/sec |

**Validation**:
- All services remain stable
- Response times within target thresholds
- No memory leaks or CPU spikes

### Scenario 2: Peak Load (High Traffic)

**Duration**: 15 minutes
**Load Pattern**: 3x baseline load

| Component | Load Profile |
|-----------|--------------|
| **NGINX** | 1500 req/sec |
| **PostgreSQL** | 600 queries/sec |
| **NATS** | 3000 msgs/sec |
| **Nuclio** | 150 function calls/sec |
| **Grafana** | 60 concurrent users |
| **S3 (Garage)** | 150 PUT/sec, 600 GET/sec |

**Validation**:
- Response times increase but stay within warning thresholds
- No errors or service failures
- Resource utilization < 80%

### Scenario 3: Stress Test (Breaking Point)

**Duration**: Until failure or 60 minutes
**Load Pattern**: Gradually increasing load

| Phase | Duration | Load Multiplier | Goal |
|-------|----------|-----------------|------|
| Warm-up | 5 min | 1x baseline | Stabilize |
| Ramp-up | 30 min | 1x → 10x | Identify limits |
| Sustain | 15 min | Max stable load | Verify stability |
| Cool-down | 10 min | 10x → 1x | Recovery test |

**Success Criteria**:
- Identify maximum sustainable load for each component
- System degrades gracefully (no crashes)
- Recovery time < 5 minutes

### Scenario 4: Spike Test (Burst Traffic)

**Duration**: 20 minutes
**Load Pattern**: Sudden traffic spikes

```
Baseline → Spike (10x) → Baseline
5 min       2 min          3 min    (repeat 2x)
```

**Validation**:
- Services handle sudden load increases
- Autoscaling mechanisms work (if enabled)
- No request timeouts or data loss

### Scenario 5: Endurance Test (Soak Test)

**Duration**: 24 hours
**Load Pattern**: Constant baseline load

**Validation**:
- No memory leaks
- No performance degradation over time
- Log rotation works properly
- Disk space doesn't fill up

### Scenario 6: Failure Recovery Test

**Test Sequence**:
1. Run baseline load
2. Kill critical service (e.g., PostgreSQL)
3. Measure recovery time
4. Verify data consistency

**Components to Test**:
- PostgreSQL restart
- NGINX restart
- Keycloak restart
- NATS restart
- Bento restart

**Success Criteria**:
- Service recovers within 60 seconds
- No data loss
- Dependent services reconnect automatically

---

## 4. Load Testing Tools

### 4.1 HTTP Load Testing

#### Apache Bench (Quick Tests)
```bash
# Simple GET request test
ab -n 10000 -c 100 http://localhost:8080/

# POST requests
ab -n 1000 -c 50 -p data.json -T application/json \
   http://localhost:8080/api/endpoint
```

#### wrk (Advanced HTTP Benchmarking)
```bash
# Install wrk
sudo apt-get install wrk  # Ubuntu/Debian
brew install wrk          # macOS

# Basic test - 10 threads, 100 connections, 30 seconds
wrk -t10 -c100 -d30s http://localhost:8080/

# With custom script
wrk -t10 -c100 -d30s -s script.lua http://localhost:8080/

# Authenticated requests
wrk -t10 -c100 -d30s -H "Authorization: Bearer $TOKEN" \
    http://localhost:8080/grafana/
```

**wrk script example** (`script.lua`):
```lua
-- Random endpoints
paths = {"/grafana/", "/prometheus/", "/"}
counter = 0

request = function()
   counter = counter + 1
   path = paths[math.random(#paths)]
   return wrk.format("GET", path)
end

response = function(status, headers, body)
   if status ~= 200 then
      print("Error: " .. status)
   end
end
```

#### Locust (Python-based Load Testing)
```bash
# Install
pip install locust

# Run test
locust -f locustfile.py --host=http://localhost:8080
```

**locustfile.py**:
```python
from locust import HttpUser, task, between

class TAVUser(HttpUser):
    wait_time = between(1, 3)

    @task(3)
    def view_grafana(self):
        self.client.get("/grafana/")

    @task(2)
    def view_prometheus(self):
        self.client.get("/prometheus/")

    @task(1)
    def query_api(self):
        self.client.get("/api/v1/query")
```

### 4.2 Database Load Testing

#### pgbench (PostgreSQL)
```bash
# Initialize test database
docker compose exec postgres pgbench -i -U tav_admin tav

# Run test: 10 clients, 100 transactions each
docker compose exec postgres pgbench -c 10 -t 100 -U tav_admin tav

# Continuous test for 60 seconds
docker compose exec postgres pgbench -c 50 -T 60 -U tav_admin tav

# Custom SQL script
docker compose exec postgres pgbench -c 10 -t 100 -f custom.sql -U tav_admin tav
```

**custom.sql**:
```sql
\set id random(1, 10000)
SELECT * FROM users WHERE id = :id;
UPDATE users SET last_seen = NOW() WHERE id = :id;
```

### 4.3 NATS Load Testing

#### nats bench (Official Tool)
```bash
# Install
go install github.com/nats-io/nats.go/examples/nats-bench@latest

# Publish test: 1M messages, 10 publishers
nats bench --server localhost:4222 --pub 10 --msgs 100000 events.test

# Subscribe test
nats bench --server localhost:4222 --sub 10 --msgs 100000 events.test

# Combined pub/sub
nats bench --server localhost:4222 --pub 5 --sub 5 --msgs 50000 events.test

# Measure latency
nats bench --server localhost:4222 --pub 1 --sub 1 --msgs 10000 \
           --size 1024 events.perf
```

### 4.4 S3 (Garage) Load Testing

#### s3-benchmark
```bash
# Install
go install github.com/dvassallo/s3-benchmark@latest

# Run test
s3-benchmark \
  -endpoint http://localhost:3900 \
  -accessKey $LOKI_S3_ACCESS_KEY \
  -secretKey $LOKI_S3_SECRET_KEY \
  -bucket tav-storage \
  -region tav-region \
  -numSamples 1000 \
  -objectSize 1048576
```

#### s3cmd (Manual Testing)
```bash
# Upload test
for i in {1..100}; do
  dd if=/dev/urandom of=file$i.bin bs=1M count=10
  s3cmd put file$i.bin s3://tav-storage/
done

# Download test
time s3cmd get s3://tav-storage/file1.bin
```

### 4.5 Serverless Function Load Testing

#### Nuclio Function Load Test
```bash
# Using wrk
wrk -t10 -c100 -d30s \
    -H "Content-Type: application/json" \
    -s nuclio-test.lua \
    http://localhost:8080/

# Using hey
hey -n 10000 -c 100 -m POST \
    -H "Content-Type: application/json" \
    -d '{"test": "data"}' \
    http://localhost:8080/
```

---

## 5. Test Execution Plan

### Phase 1: Component Isolation Tests (Week 1)

Test each component independently:

**Day 1-2: Database Layer**
- PostgreSQL query performance
- PgBouncer connection pooling
- Write vs. read throughput

**Day 3: Ingress & Auth**
- NGINX throughput
- OAuth2-Proxy latency
- Keycloak login performance

**Day 4: Observability**
- Prometheus scrape performance
- Loki ingestion rate
- Grafana query performance

**Day 5: Messaging & Processing**
- NATS message throughput
- Bento processing rate
- End-to-end latency

**Day 6-7: Compute & Storage**
- Nuclio function performance
- Garage S3 operations
- Cold start measurements

### Phase 2: Integration Tests (Week 2)

Test combined workflows:

**Scenario A: Event Processing Pipeline**
```
Nuclio → NATS → Bento → PostgreSQL
```
- Measure end-to-end latency
- Test throughput limits
- Monitor resource usage

**Scenario B: Logging Pipeline**
```
Application → NATS → Bento → Loki → Grafana
```
- Log ingestion rate
- Query performance
- Storage efficiency

**Scenario C: Authentication Flow**
```
Client → NGINX → OAuth2 → Keycloak → Backend
```
- Login latency
- Token validation overhead
- Session management

### Phase 3: Stress Testing (Week 3)

Run all load scenarios:
- Baseline load (8 hours)
- Peak load (4 hours)
- Stress test (until breaking point)
- Spike test (2 hours)
- Endurance test (24 hours)

### Phase 4: Analysis & Optimization (Week 4)

- Analyze bottlenecks
- Tune configurations
- Re-run critical tests
- Document findings

---

## 6. Monitoring During Tests

### Real-Time Monitoring

#### Prometheus Queries Dashboard

Create Grafana dashboard with these queries:

```promql
# Request rate
sum(rate(nginx_http_requests_total[5m])) by (status)

# Response time percentiles
histogram_quantile(0.95,
  rate(nginx_http_request_duration_seconds_bucket[5m]))

# Error rate
sum(rate(nginx_http_requests_total{status=~"5.."}[5m])) /
sum(rate(nginx_http_requests_total[5m])) * 100

# CPU usage by container
rate(container_cpu_usage_seconds_total[5m]) * 100

# Memory usage
container_memory_usage_bytes / 1024 / 1024 / 1024

# Database connections
pg_stat_database_numbackends

# NATS message rate
rate(nats_core_total_msgs[5m])
```

#### Container Resource Monitoring
```bash
# Real-time stats
docker compose stats

# Continuous monitoring
watch -n 1 'docker compose ps && docker stats --no-stream'

# Export metrics
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
  --no-stream > stats.txt
```

### Logging Test Results

```bash
# Create test results directory
mkdir -p test-results/$(date +%Y%m%d-%H%M%S)

# Save Prometheus metrics
curl http://localhost:8080/prometheus/api/v1/query?query=up \
  > test-results/prometheus-up.json

# Save NATS stats
curl http://localhost:8222/varz > test-results/nats-stats.json

# Save docker stats
docker compose stats --no-stream > test-results/container-stats.txt

# Save logs
docker compose logs > test-results/all-services.log
```

---

## 7. Performance Baselines

### Expected Performance (Single Host, 16GB RAM, 8 CPU)

| Component | Metric | Expected Value |
|-----------|--------|----------------|
| **NGINX** | Requests/sec | 2000-5000 |
| **PostgreSQL** | Queries/sec | 1000-3000 |
| **PgBouncer** | Connections | 100-200 |
| **NATS** | Messages/sec | 50000-100000 |
| **Bento** | Messages/sec | 5000-10000 |
| **Nuclio** | Invocations/sec | 200-500 |
| **Garage S3** | Operations/sec | 500-1000 |
| **Prometheus** | Samples/sec | 50000-100000 |
| **Loki** | Log lines/sec | 5000-10000 |

### Resource Utilization Baselines

| Service | CPU % | Memory (MB) | Disk I/O (MB/s) |
|---------|-------|-------------|-----------------|
| postgres | 10-30% | 512-1024 | 10-50 |
| pgbouncer | 5-10% | 64-128 | 1-5 |
| keycloak | 10-20% | 768-1536 | 1-5 |
| grafana | 5-15% | 256-512 | 1-10 |
| prometheus | 15-30% | 1024-2048 | 20-100 |
| loki | 10-20% | 512-1024 | 10-50 |
| nats | 5-15% | 256-512 | 5-20 |
| bento | 5-10% | 128-256 | 5-15 |
| nuclio-dashboard | 5-10% | 256-512 | 1-5 |
| garage | 10-20% | 512-1024 | 10-50 |
| nginx | 5-10% | 64-128 | 1-5 |

---

## 8. Results Analysis Template

### Test Report Structure

```markdown
# Load Test Report - [Date]

## Test Configuration
- **Scenario**: [Baseline/Peak/Stress/etc.]
- **Duration**: [Time]
- **Load**: [Specific metrics]
- **Environment**: [Hardware specs]

## Results Summary

### Overall Performance
| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Requests/sec | 1000 | 1247 | ✅ PASS |
| P95 Latency | 500ms | 342ms | ✅ PASS |
| Error Rate | < 0.1% | 0.03% | ✅ PASS |

### Component Performance
[Table for each component]

### Resource Utilization
[CPU, Memory, Disk, Network graphs]

## Bottlenecks Identified
1. **PostgreSQL**: Connection limit reached at 180 concurrent
2. **NATS**: Message latency increased above 10000 msg/sec

## Recommendations
1. Increase PgBouncer pool size to 50
2. Tune NATS max_payload to 10MB
3. Add read replica for PostgreSQL

## Action Items
- [ ] Implement recommendations
- [ ] Re-test after tuning
- [ ] Update capacity planning docs
```

---

## 9. Optimization Checklist

### PostgreSQL Tuning
- [ ] Increase `shared_buffers` to 25% of RAM
- [ ] Tune `effective_cache_size` to 50% of RAM
- [ ] Set `max_connections` based on workload
- [ ] Enable query logging for slow queries
- [ ] Create appropriate indexes
- [ ] Run `VACUUM ANALYZE` regularly

### PgBouncer Tuning
- [ ] Adjust `default_pool_size`
- [ ] Set `max_client_conn` appropriately
- [ ] Use transaction pooling where possible
- [ ] Monitor pool saturation

### NGINX Tuning
- [ ] Increase `worker_connections`
- [ ] Tune `keepalive_timeout`
- [ ] Enable HTTP/2
- [ ] Configure rate limiting
- [ ] Add caching headers

### NATS Tuning
- [ ] Increase `max_connections`
- [ ] Tune `max_payload` size
- [ ] Configure JetStream limits
- [ ] Monitor slow consumers

### Prometheus Tuning
- [ ] Adjust scrape intervals
- [ ] Configure retention period
- [ ] Optimize query performance
- [ ] Use recording rules

### Loki Tuning
- [ ] Configure chunk size
- [ ] Set retention period
- [ ] Tune compactor settings
- [ ] Optimize query parallelism

---

## 10. Continuous Performance Monitoring

### Automated Alerts (Prometheus)

Create alerting rules in `prometheus/alert-rules.yml`:

```yaml
groups:
  - name: performance
    interval: 30s
    rules:
      # High response time
      - alert: HighResponseTime
        expr: |
          histogram_quantile(0.95,
            rate(nginx_http_request_duration_seconds_bucket[5m])
          ) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High response time detected"
          description: "P95 latency is {{ $value }}s"

      # High error rate
      - alert: HighErrorRate
        expr: |
          sum(rate(nginx_http_requests_total{status=~"5.."}[5m])) /
          sum(rate(nginx_http_requests_total[5m])) * 100 > 1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }}%"

      # Database connection saturation
      - alert: DatabaseConnectionHigh
        expr: pg_stat_database_numbackends > 150
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High database connections"
          description: "{{ $value }} connections active"

      # NATS slow consumers
      - alert: NATSSlowConsumers
        expr: nats_core_slow_consumers > 0
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "NATS slow consumers detected"
          description: "{{ $value }} slow consumers"
```

### Performance Regression Testing

Run automated performance tests on schedule:

```bash
#!/bin/bash
# performance-regression-test.sh

DATE=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="test-results/$DATE"

mkdir -p $RESULTS_DIR

echo "Running performance regression tests..."

# Run HTTP load test
wrk -t10 -c100 -d60s http://localhost:8080/ > $RESULTS_DIR/http-test.txt

# Run database test
docker compose exec postgres pgbench -c 50 -T 60 -U tav_admin tav \
  > $RESULTS_DIR/db-test.txt

# Run NATS test
nats bench --server localhost:4222 --pub 5 --sub 5 --msgs 100000 events.test \
  > $RESULTS_DIR/nats-test.txt

# Collect metrics
curl http://localhost:8080/prometheus/api/v1/query?query=up \
  > $RESULTS_DIR/prometheus-metrics.json

# Compare with baseline
python3 compare-performance.py $RESULTS_DIR baseline/

echo "Results saved to: $RESULTS_DIR"
```

---

## 11. Capacity Planning

### Growth Projections

| Period | Expected Load Increase | Required Action |
|--------|------------------------|-----------------|
| **3 months** | +50% | Monitor resource usage |
| **6 months** | +100% | Scale PostgreSQL (replica) |
| **9 months** | +200% | Add NATS cluster nodes |
| **12 months** | +300% | Multi-host deployment |

### Scaling Triggers

| Metric | Current | Scale at | Action |
|--------|---------|----------|--------|
| **Requests/sec** | 1000 | 3000 | Add NGINX instances |
| **DB Connections** | 50 | 150 | Add PgBouncer instance |
| **NATS Messages/sec** | 5000 | 40000 | Add NATS nodes |
| **Storage** | 10GB | 80GB | Expand Garage cluster |

---

## 12. Appendix

### A. Test Data Generators

#### Generate Random JSON
```bash
#!/bin/bash
# generate-test-data.sh

for i in {1..1000}; do
  echo "{
    \"id\": $i,
    \"timestamp\": \"$(date -Iseconds)\",
    \"user\": \"user$((RANDOM % 100))\",
    \"action\": \"$(shuf -n1 -e login logout update delete)\",
    \"value\": $((RANDOM % 1000))
  }"
done
```

#### SQL Data Generator
```sql
-- Generate test users
INSERT INTO users (username, email, created_at)
SELECT
  'user' || generate_series,
  'user' || generate_series || '@example.com',
  NOW() - (random() * interval '365 days')
FROM generate_series(1, 10000);
```

### B. Useful Commands Cheat Sheet

```bash
# Quick performance check
docker compose top

# Network traffic
docker compose exec nginx tail -f /var/log/nginx/access.log

# Database activity
docker compose exec postgres pg_stat_activity

# NATS connections
curl -s http://localhost:8222/connz | jq '.connections | length'

# Prometheus targets
curl -s http://localhost:8080/prometheus/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Disk usage
docker system df
docker compose exec postgres df -h
```

### C. Performance Testing Tools Matrix

| Tool | Use Case | Learning Curve | Best For |
|------|----------|----------------|----------|
| **ab** | Quick HTTP tests | Easy | Simple benchmarks |
| **wrk** | HTTP load testing | Medium | Realistic scenarios |
| **Locust** | Complex user flows | Medium | Multi-step workflows |
| **pgbench** | Database testing | Easy | PostgreSQL performance |
| **nats bench** | Message throughput | Easy | NATS performance |
| **Gatling** | Enterprise testing | Hard | CI/CD integration |
| **k6** | Modern load testing | Medium | DevOps workflows |

---

**Document Version**: 1.0
**Last Updated**: 2026-02-01
**Next Review**: 2026-03-01
