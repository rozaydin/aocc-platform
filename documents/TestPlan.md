# TAV Platform Performance Test Plan

## Executive Summary

This document defines the test plan for measuring and validating the TAV data platform's performance characteristics. The focus is on **event streaming** (NATS → Bento) and **serverless functions** (Nuclio), targeting **1K-10K events/second** throughput.

**Goals:**
1. Establish performance baselines for all critical paths
2. Validate SLA requirements (latency, throughput, availability)
3. Identify capacity limits and bottlenecks for infrastructure planning

---

## Test Scope

### In Scope
| Component | Test Focus |
|-----------|------------|
| **NATS** | Message throughput, latency, JetStream durability |
| **Bento** | Stream processing throughput, transformation latency |
| **Nuclio** | Function invocation latency, concurrent execution, cold starts |
| **Garage** | S3 PUT/GET throughput, latency under load |
| **PostgreSQL + PgBouncer** | Query latency, connection pool efficiency |
| **Loki** | Log ingestion rate, query performance |
| **End-to-end** | Full pipeline latency from event publish to final destination |

### Out of Scope
- Authentication/authorization performance (Keycloak/OAuth2-Proxy)
- Grafana dashboard rendering performance
- Network-level testing (assumed stable container network)

---

## Key Performance Indicators (KPIs)

### 1. NATS Message Broker

| KPI | Metric | Target | Critical Threshold |
|-----|--------|--------|-------------------|
| **Throughput** | Messages/second | ≥10,000 msg/s | <1,000 msg/s |
| **Publish Latency (p50)** | Time to acknowledge | <5ms | >50ms |
| **Publish Latency (p99)** | Time to acknowledge | <20ms | >100ms |
| **Consumer Lag** | Messages behind head | <100 msgs | >10,000 msgs |
| **JetStream Ack Latency** | Durable ack time | <10ms | >100ms |
| **Connection Count** | Active connections | Monitor | >900 (limit: 1000) |
| **Memory Usage** | JetStream memory | Monitor | >900MB (limit: 1GB) |
| **Disk Usage** | JetStream storage | Monitor | >9GB (limit: 10GB) |

**Prometheus Metrics:**
- `nats_server_total_messages`
- `nats_server_total_bytes`
- `nats_server_connections`
- `nats_jetstream_server_memory_used`
- `nats_jetstream_server_storage_used`

### 2. Bento Stream Processor

| KPI | Metric | Target | Critical Threshold |
|-----|--------|--------|-------------------|
| **Processing Throughput** | Events/second | ≥10,000 evt/s | <1,000 evt/s |
| **Processing Latency (p50)** | Input to output | <10ms | >100ms |
| **Processing Latency (p99)** | Input to output | <50ms | >500ms |
| **Backpressure** | Input queue depth | <1,000 | >10,000 |
| **Error Rate** | Failed messages | <0.01% | >1% |
| **Batch Efficiency** | Messages per batch | Monitor | - |

**Prometheus Metrics:**
- `bento_input_received_total`
- `bento_output_sent_total`
- `bento_processor_latency_ns`
- `bento_input_connection_up`

### 3. Nuclio Serverless Functions

| KPI | Metric | Target | Critical Threshold |
|-----|--------|--------|-------------------|
| **Invocation Latency (p50)** | Request to response | <50ms | >200ms |
| **Invocation Latency (p99)** | Request to response | <200ms | >1000ms |
| **Cold Start Time** | First invocation | <500ms | >2000ms |
| **Concurrent Executions** | Parallel invocations | ≥100 | <10 |
| **Throughput** | Invocations/second | ≥1,000 inv/s | <100 inv/s |
| **Error Rate** | Failed invocations | <0.1% | >1% |
| **Function Timeout Rate** | Timeouts/total | <0.01% | >0.1% |

**Prometheus Metrics:**
- `nuclio_function_calls_total`
- `nuclio_function_call_duration_milliseconds`
- `nuclio_function_call_errors_total`

### 4. Garage Object Storage (S3)

| KPI | Metric | Target | Critical Threshold |
|-----|--------|--------|-------------------|
| **PUT Throughput** | Objects/second | ≥500 obj/s | <50 obj/s |
| **PUT Latency (p50)** | Time to complete | <50ms | >500ms |
| **GET Throughput** | Objects/second | ≥1,000 obj/s | <100 obj/s |
| **GET Latency (p50)** | Time to first byte | <20ms | >200ms |
| **Bandwidth** | MB/second | Monitor | - |

**Prometheus Metrics:**
- `garage_api_request_duration_seconds`
- `garage_api_request_total`
- `garage_block_read_duration_seconds`

### 5. PostgreSQL + PgBouncer

| KPI | Metric | Target | Critical Threshold |
|-----|--------|--------|-------------------|
| **Query Latency (p50)** | Simple SELECT | <5ms | >50ms |
| **Query Latency (p99)** | Simple SELECT | <20ms | >200ms |
| **Transactions/second** | TPS | ≥1,000 TPS | <100 TPS |
| **Connection Pool Utilization** | Active/Total | <80% | >95% |
| **Pool Wait Time** | Client wait for conn | <10ms | >100ms |
| **Cache Hit Ratio** | Buffer cache | >95% | <80% |

**Prometheus Metrics:**
- `pg_stat_activity_count`
- `pg_stat_database_tup_fetched`
- `pg_stat_database_blks_hit` / `pg_stat_database_blks_read`
- `pgbouncer_pools_client_active`

### 6. Loki Log Aggregation

| KPI | Metric | Target | Critical Threshold |
|-----|--------|--------|-------------------|
| **Ingestion Rate** | Log lines/second | ≥10,000 lines/s | <1,000 lines/s |
| **Ingestion Latency** | Write acknowledgment | <100ms | >1000ms |
| **Query Latency (p50)** | Simple label query | <500ms | >5000ms |
| **Query Latency (p99)** | Simple label query | <2000ms | >10000ms |
| **Compaction Lag** | Pending compaction | Monitor | >1h behind |

**Prometheus Metrics:**
- `loki_distributor_lines_received_total`
- `loki_request_duration_seconds`
- `loki_ingester_chunk_stored_bytes_total`

### 7. End-to-End Pipeline

| KPI | Metric | Target | Critical Threshold |
|-----|--------|--------|-------------------|
| **E2E Latency (p50)** | Publish → Final destination | <100ms | >1000ms |
| **E2E Latency (p99)** | Publish → Final destination | <500ms | >5000ms |
| **Data Loss Rate** | Lost/Total messages | 0% | >0.01% |
| **Out-of-Order Rate** | Misordered messages | <0.1% | >1% |

---

## Test Scenarios

### Scenario 1: NATS Throughput Baseline

**Objective:** Determine maximum sustainable message throughput

**Setup:**
- Message size: 1KB JSON payload
- Pattern: Publish to `events.test.load`
- Duration: 5 minutes sustained

**Test Cases:**
| Test | Rate | Description |
|------|------|-------------|
| 1.1 | 1,000 msg/s | Baseline load |
| 1.2 | 5,000 msg/s | Medium load |
| 1.3 | 10,000 msg/s | Target load |
| 1.4 | Ramp to failure | Find breaking point |

**Measurements:**
- Actual throughput achieved
- Publish latency percentiles
- JetStream acknowledgment latency
- Resource utilization (CPU, memory)

---

### Scenario 2: Bento Stream Processing

**Objective:** Measure stream processing throughput and latency

**Setup:**
- Input: NATS `events.>` wildcard subscription
- Transform: JSON parse + enrichment (as configured)
- Output: stdout (or configure to NATS/DB for realistic test)

**Test Cases:**
| Test | Input Rate | Payload | Description |
|------|------------|---------|-------------|
| 2.1 | 1,000 msg/s | 1KB | Baseline processing |
| 2.2 | 5,000 msg/s | 1KB | Medium load |
| 2.3 | 10,000 msg/s | 1KB | Target load |
| 2.4 | 5,000 msg/s | 10KB | Large payload test |
| 2.5 | Burst 50K | 1KB | Burst handling (5s burst) |

**Measurements:**
- Processing latency (input timestamp vs output timestamp)
- Backpressure indicators
- Consumer lag vs input rate
- Memory usage under load

---

### Scenario 3: Nuclio Function Performance

**Objective:** Measure serverless function invocation characteristics

**Setup:**
- Deploy test function (simple echo or transform)
- Trigger via HTTP and NATS

**Test Cases:**
| Test | Concurrency | Rate | Description |
|------|-------------|------|-------------|
| 3.1 | 1 | 10 req/s | Cold start measurement |
| 3.2 | 10 | 100 req/s | Warm concurrent |
| 3.3 | 50 | 500 req/s | High concurrency |
| 3.4 | 100 | 1,000 req/s | Target load |
| 3.5 | NATS trigger | 1,000 evt/s | Event-driven invocation |

**Measurements:**
- Cold start time (first invocation after idle)
- Warm invocation latency
- Throughput at various concurrency levels
- Error rate under load

---

### Scenario 4: End-to-End Pipeline

**Objective:** Measure complete data flow latency and reliability

**Pipeline:** `Publisher → NATS → Bento → [transform] → Nuclio → Garage/DB`

**Test Cases:**
| Test | Rate | Duration | Description |
|------|------|----------|-------------|
| 4.1 | 100 msg/s | 10 min | Low load, measure baseline |
| 4.2 | 1,000 msg/s | 10 min | Medium load |
| 4.3 | 5,000 msg/s | 30 min | Sustained load |
| 4.4 | 10,000 msg/s | 10 min | Target load |

**Measurements:**
- End-to-end latency (embed timestamp in payload, compare at destination)
- Message loss (count at source vs destination)
- Ordering preservation
- Bottleneck identification (which component queues up first)

---

### Scenario 5: Storage Performance

**Objective:** Measure Garage S3 and PostgreSQL performance

**Garage Tests:**
| Test | Operation | Object Size | Concurrency |
|------|-----------|-------------|-------------|
| 5.1 | PUT | 1KB | 10 |
| 5.2 | PUT | 1MB | 10 |
| 5.3 | GET | 1KB | 50 |
| 5.4 | GET | 1MB | 50 |
| 5.5 | Mixed | 1KB-1MB | 50 |

**PostgreSQL Tests:**
| Test | Query Type | Concurrency | Description |
|------|-----------|-------------|-------------|
| 5.6 | SELECT by PK | 100 | Point lookups |
| 5.7 | INSERT | 100 | Write throughput |
| 5.8 | Mixed R/W | 100 | 80% read, 20% write |

---

### Scenario 6: Chaos/Resilience Testing

**Objective:** Verify system behavior under failure conditions

**Test Cases:**
| Test | Failure Mode | Expected Behavior |
|------|--------------|-------------------|
| 6.1 | Kill NATS container | Bento reconnects, no message loss (JetStream) |
| 6.2 | Kill Bento container | Messages queue in NATS, resume on restart |
| 6.3 | Kill Nuclio function | Retry/DLQ behavior |
| 6.4 | Garage unavailable | Loki/Nuclio degrade gracefully |
| 6.5 | PostgreSQL restart | PgBouncer handles reconnection |
| 6.6 | Network partition | Timeout handling, no data corruption |

---

## Recommended Testing Tools

### For NATS Testing

**nats-bench** (Official NATS benchmark tool)
```bash
# Install
go install github.com/nats-io/natscli/nats@latest

# Publish benchmark
nats bench test --pub 10 --msgs 100000 --size 1024

# Request/Reply benchmark
nats bench test --pub 5 --sub 5 --msgs 50000 --size 1024
```

**nats CLI for JetStream**
```bash
# Create test stream
nats stream add TEST --subjects "events.>" --storage file --retention limits

# Publish test messages
nats pub events.test.load --count 10000 '{"timestamp":"{{Time}}", "data":"test"}'
```

### For HTTP/Function Testing

**k6** (Recommended - integrates with Grafana)
```bash
# Install
brew install k6  # or download from k6.io

# Example script for Nuclio
cat > nuclio-test.js << 'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '1m', target: 100 },  // Ramp up
    { duration: '5m', target: 100 },  // Sustained
    { duration: '1m', target: 0 },    // Ramp down
  ],
};

export default function () {
  const res = http.post('http://localhost:8080/nuclio/your-function',
    JSON.stringify({ data: 'test' }),
    { headers: { 'Content-Type': 'application/json' } }
  );
  check(res, { 'status is 200': (r) => r.status === 200 });
}
EOF

k6 run nuclio-test.js
```

### For S3/Garage Testing

**s3-benchmark** or **warp**
```bash
# Using warp (MinIO's benchmark tool, works with S3-compatible)
warp mixed --host=localhost:3900 --access-key=KEY --secret-key=SECRET \
  --duration=5m --concurrent=50

# Using aws-cli for simple tests
aws --endpoint-url http://localhost:3900 s3 cp testfile s3://bucket/
```

### For PostgreSQL Testing

**pgbench** (Built into PostgreSQL)
```bash
# Initialize
pgbench -i -s 10 -h localhost -p 6432 -U postgres tav

# Run benchmark
pgbench -c 100 -j 10 -T 300 -h localhost -p 6432 -U postgres tav
```

### For End-to-End Testing

**Custom Script Approach:**
```bash
#!/bin/bash
# Publish with embedded timestamp, measure at destination
START=$(date +%s%N)
nats pub events.test.e2e "{\"ts\":$START,\"id\":\"$(uuidgen)\"}"
# Measure when message arrives at final destination
```

### For Observability During Tests

- **Grafana dashboards** — Real-time visualization of all Prometheus metrics
- **Loki** — Correlate logs with performance anomalies
- **cAdvisor** — Container resource consumption during load

---

## Test Environment Requirements

### Resource Baseline (Before Testing)
Document current resource allocation:
- Total CPU cores available
- Total memory available
- Disk I/O capacity
- Network bandwidth

### Test Data
- Generate realistic JSON payloads (1KB, 10KB sizes)
- Pre-create test streams/queues in NATS
- Pre-create test buckets in Garage
- Seed PostgreSQL with baseline data if needed

### Monitoring Setup
- Ensure Prometheus scrape targets are all healthy
- Create/import Grafana dashboards for load test visualization
- Configure alerts for critical thresholds during testing

---

## Success Criteria

### Baseline Test Pass Criteria
- [ ] All components handle **1,000 events/second** sustained for 10 minutes
- [ ] P99 latency remains below critical thresholds
- [ ] No message loss detected
- [ ] No OOM kills or container restarts

### Target Test Pass Criteria
- [ ] All components handle **10,000 events/second** sustained for 5 minutes
- [ ] P50 latency within target ranges
- [ ] P99 latency within target ranges
- [ ] Error rate <0.1%
- [ ] Resource utilization <80% at target load

### Capacity Planning Output
- [ ] Maximum throughput identified per component
- [ ] Bottleneck component identified
- [ ] Resource scaling recommendations documented
- [ ] SLA recommendations based on measured performance

---

## Test Execution Schedule

| Phase | Duration | Focus |
|-------|----------|-------|
| **Phase 1: Component Baselines** | 1-2 days | Individual component benchmarks |
| **Phase 2: Integration Tests** | 1 day | NATS→Bento, Bento→Nuclio paths |
| **Phase 3: End-to-End Load** | 1-2 days | Full pipeline at scale |
| **Phase 4: Chaos Testing** | 1 day | Failure scenarios |
| **Phase 5: Analysis & Report** | 1 day | Compile results, recommendations |

---

## Deliverables

1. **Baseline Metrics Report** — Current performance characteristics
2. **Capacity Limits Report** — Breaking points per component
3. **Bottleneck Analysis** — Identified constraints and recommendations
4. **SLA Recommendations** — Achievable guarantees based on testing
5. **Grafana Dashboards** — Load test visualization (exportable)
6. **Runbook** — Repeatable test execution procedures
