#!/usr/bin/gnuplot

# Platform Memory Usage
set terminal pngcairo size 1400,700 enhanced font 'Arial,12'
set output 'memory-usage.png'

set title "Platform-Wide Memory Usage" font 'Arial,16'
set style data histogram
set style histogram cluster gap 1
set style fill solid border -1
set boxwidth 0.9
set grid ytics
set ylabel "Memory Usage (MiB)"
set yrange [0:1100]
set xtics rotate by -45 font 'Arial,10'

plot '-' using 2:xtic(1) title 'Memory (MiB)' lc rgb "#1976D2"
Keycloak 941
Prometheus 300
PostgreSQL 222
cAdvisor 169
Grafana 113
Loki 90
Alloy 64
Nuclio 41
Bento 37
NGINX 13
PgBouncer 2
OAuth2-Proxy 8
Postgres-Exp 9
Garage 7
NATS 6
Alertmanager 19
e
