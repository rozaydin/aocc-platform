#!/usr/bin/gnuplot

# Performance vs Targets - Margin Analysis
set terminal pngcairo size 1200,700 enhanced font 'Arial,12'
set output 'performance-vs-targets.png'

set title "Performance Margins: Actual vs Target (Higher is Better)" font 'Arial,16'
set style data histogram
set style histogram cluster gap 1
set style fill solid border -1
set boxwidth 0.9
set grid ytics
set ylabel "Performance Multiplier (x times above target)"
set yrange [0:550]
set xtics rotate by -45 font 'Arial,10'

# Add reference line at 1x (meeting target)
set arrow from -0.5,1 to 9.5,1 nohead lt 2 lc rgb "red" lw 2
set label "Target (1x)" at 8,10 textcolor rgb "red"

# Color based on performance
plot '-' using 2:xtic(1) title 'Performance Margin' lc rgb "#2E7D32"
"PostgreSQL\nLoad TPS" 17.6
"PostgreSQL\nBaseline TPS" 6.0
"NGINX\nLoad" 10.9
"NGINX\nBaseline" 8.4
"OAuth2-Proxy\nThroughput" 4.7
"Prometheus\nRange Query" 200
"Prometheus\nInstant Query" 100
"Loki\nLog Query" 500
"Loki\nLabels Query" 25
e
