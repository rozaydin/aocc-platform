#!/usr/bin/gnuplot

# Ingress & Authentication Performance
set terminal pngcairo size 1200,600 enhanced font 'Arial,12'
set output 'ingress-performance.png'

set multiplot layout 1,2 title "Phase 2: Ingress & Authentication Performance" font 'Arial,16'

# Throughput Chart
set style data histogram
set style histogram cluster gap 1
set style fill solid border -1
set boxwidth 0.9
set grid ytics
set ylabel "Requests Per Second"
set title "HTTP Throughput"
set yrange [0:6000]

# Add target line
set arrow from -0.5,500 to 2.5,500 nohead lt 2 lc rgb "red" lw 2

plot '-' using 2:xtic(1) title 'Actual' lc rgb "#2E7D32", \
     500 title 'Target (500 req/s)' with lines lc rgb "#D32F2F" lw 2
"NGINX\nBaseline" 4206.94
"NGINX\nLoad" 5458.64
OAuth2-Proxy 2335.85
e

# Latency Chart
set ylabel "Latency (milliseconds)"
set title "HTTP Latency"
set yrange [0:100]
set arrow from -0.5,100 to 2.5,100 nohead lt 2 lc rgb "orange" lw 2

plot '-' using 2:xtic(1) title 'Actual' lc rgb "#1976D2", \
     100 title 'Target (100ms)' with lines lc rgb "#F57C00" lw 2
"NGINX\nBaseline" 24.54
"NGINX\nLoad" 37.00
OAuth2-Proxy 21.92
e

unset multiplot
