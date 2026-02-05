#!/usr/bin/gnuplot

# Database Performance - TPS and Latency
set terminal pngcairo size 1200,600 enhanced font 'Arial,12'
set output 'database-performance.png'

set multiplot layout 1,2 title "Phase 1: Database Layer Performance" font 'Arial,16'

# TPS Chart
set style data histogram
set style histogram cluster gap 1
set style fill solid border -1
set boxwidth 0.9
set xtics format ""
set grid ytics
set ylabel "Transactions Per Second (TPS)"
set title "PostgreSQL Throughput"
set yrange [0:10000]

# Add target line
set arrow from -0.5,1000 to 1.5,1000 nohead lt 2 lc rgb "red" lw 2

plot '-' using 2:xtic(1) title 'Actual TPS' lc rgb "#2E7D32", \
     '-' using 2 title 'Target' lc rgb "#D32F2F"
Baseline 6035.8
Load 8787.8
e
Baseline 1000
Load 500
e

# Latency Chart
set ylabel "Latency (milliseconds)"
set title "PostgreSQL Latency"
set yrange [0:100]
set arrow from -0.5,50 to 1.5,50 nohead lt 2 lc rgb "orange" lw 2

plot '-' using 2:xtic(1) title 'Actual Latency' lc rgb "#1976D2", \
     '-' using 2 title 'Target' lc rgb "#F57C00"
Baseline 1.657
Load 5.690
e
Baseline 50
Load 100
e

unset multiplot
