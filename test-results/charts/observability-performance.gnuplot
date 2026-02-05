#!/usr/bin/gnuplot

# Observability Stack Performance
set terminal pngcairo size 1200,500 enhanced font 'Arial,12'
set output 'observability-performance.png'

set title "Phase 3: Observability Query Performance" font 'Arial,16'
set style data histogram
set style histogram cluster gap 1
set style fill solid border -1
set boxwidth 0.9
set grid ytics
set ylabel "Response Time (milliseconds)"
set yrange [0:150]
set xtics rotate by -45

# Add target lines
set arrow from -0.5,100 to 4.5,100 nohead lt 2 lc rgb "orange" lw 1.5 dashtype 2
set label "Target: 100-5000ms" at 3.5,110 textcolor rgb "orange"

plot '-' using 2:xtic(1) title 'Actual Performance' lc rgb "#1976D2"
"Prometheus\nRange Query" 0.01
"Prometheus\nInstant Query" 0.01
"Grafana\nAPI" 0.01
"Loki\nLabels" 80
"Loki\nLogs" 10
e
