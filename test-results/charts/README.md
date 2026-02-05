# TAV Architecture Performance Charts

This directory contains visual performance charts generated from load testing results.

## Generated Charts

### 1. Database Performance (`database-performance.png`)
**Phase 1 Results**

Two-panel chart showing:
- **Left**: PostgreSQL Throughput (TPS)
  - Baseline: 6,035 TPS (10 clients)
  - Load: 8,787 TPS (50 clients)
  - Target: 1,000 TPS minimum

- **Right**: PostgreSQL Latency
  - Baseline: 1.66ms
  - Load: 5.69ms
  - Target: <50ms baseline, <100ms load

**Key Finding**: Database performs 17x above target under load

---

### 2. Ingress & Authentication Performance (`ingress-performance.png`)
**Phase 2 Results**

Two-panel chart showing:
- **Left**: HTTP Throughput (req/sec)
  - NGINX Baseline: 4,207 req/s
  - NGINX Load: 5,459 req/s
  - OAuth2-Proxy: 2,336 req/s
  - Target: >500 req/s

- **Right**: HTTP Latency
  - NGINX Baseline: 24.54ms
  - NGINX Load: 37.00ms
  - OAuth2-Proxy: 21.92ms
  - Target: <100ms

**Key Finding**: All services exceed 500 req/s target by 4-10x

---

### 3. Observability Performance (`observability-performance.png`)
**Phase 3 Results**

Single chart showing query response times:
- Prometheus Range Query: <0.01ms
- Prometheus Instant Query: <0.01ms
- Grafana API: <0.01ms
- Loki Labels: 80ms
- Loki Logs: 10ms
- Target: 100-5000ms

**Key Finding**: All queries 25-500x faster than targets

---

### 4. Memory Usage (`memory-usage.png`)
**Platform-Wide Resource Usage**

Bar chart showing memory consumption across all 16 services:
- Highest: Keycloak (941 MiB) - JVM-based identity provider
- Prometheus: 300 MiB - Time-series database
- PostgreSQL: 222 MiB - Relational database
- Others: <170 MiB each
- **Total**: ~2.2 GB (3.7% of 58.74 GB available)

**Key Finding**: Excellent resource efficiency across the platform

---

### 5. Performance vs Targets (`performance-vs-targets.png`)
**Margin Analysis**

Bar chart showing how much performance exceeds targets:
- Loki Log Query: **500x faster** than target
- Prometheus Range Query: **200x faster**
- Prometheus Instant Query: **100x faster**
- Loki Labels Query: **25x faster**
- PostgreSQL Load TPS: **17.6x above** target
- NGINX Load: **10.9x above** target
- NGINX Baseline: **8.4x above** target
- PostgreSQL Baseline TPS: **6x above** target
- OAuth2-Proxy: **4.7x above** target

**Key Finding**: Platform exceeds all performance targets with significant margins

---

## Regenerating Charts

To regenerate all charts:

```bash
cd test-results/charts
./generate-all.sh
```

### Prerequisites

Install gnuplot:
- **Ubuntu/Debian**: `sudo apt-get install gnuplot`
- **macOS**: `brew install gnuplot`
- **RHEL/Fedora**: `sudo dnf install gnuplot`

### Individual Charts

Generate specific charts:

```bash
gnuplot database-performance.gnuplot
gnuplot ingress-performance.gnuplot
gnuplot observability-performance.gnuplot
gnuplot memory-usage.gnuplot
gnuplot performance-vs-targets.gnuplot
```

---

## Chart Files

| File | Size | Description |
|------|------|-------------|
| `database-performance.png` | ~43 KB | Phase 1: PostgreSQL TPS and latency |
| `ingress-performance.png` | ~45 KB | Phase 2: NGINX and OAuth2-Proxy throughput/latency |
| `observability-performance.png` | ~41 KB | Phase 3: Query performance (Prometheus, Loki, Grafana) |
| `memory-usage.png` | ~42 KB | Platform-wide memory consumption |
| `performance-vs-targets.png` | ~50 KB | Performance margin analysis (actual vs targets) |

**Total**: ~220 KB for all charts

---

## Viewing Charts

### Linux
```bash
xdg-open *.png
```

### macOS
```bash
open *.png
```

### Windows (WSL)
```bash
explorer.exe .
```

---

## Chart Customization

To modify charts, edit the corresponding `.gnuplot` files:

- Adjust colors: Change `lc rgb "#RRGGBB"` values
- Modify size: Change `set terminal pngcairo size WIDTH,HEIGHT`
- Update fonts: Change `font 'Arial,12'` to desired font and size
- Add labels: Use `set label "text" at x,y`
- Change ranges: Modify `set yrange [min:max]`

After editing, regenerate with `./generate-all.sh`

---

## Data Sources

Charts are generated from:
- Raw test results: `../raw-data/phase{1-5}/`
- Consolidated data: `../consolidated-results.csv`
- Test summaries: `../raw-data/phase{1-5}/summary.md`

---

Generated: 2026-02-05
Test Duration: ~20 minutes across 5 phases
Platform: TAV Architecture (16 services)
