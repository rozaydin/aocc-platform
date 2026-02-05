#!/bin/bash

# Generate all charts using gnuplot

echo "Generating performance charts..."

cd "$(dirname "$0")"

# Check if gnuplot is installed
if ! command -v gnuplot &> /dev/null; then
    echo "ERROR: gnuplot is not installed"
    echo "Install with: sudo apt-get install gnuplot (Ubuntu/Debian)"
    echo "           or: brew install gnuplot (macOS)"
    exit 1
fi

# Generate each chart
echo "  [1/5] Database performance..."
gnuplot database-performance.gnuplot

echo "  [2/5] Ingress & authentication performance..."
gnuplot ingress-performance.gnuplot

echo "  [3/5] Observability performance..."
gnuplot observability-performance.gnuplot

echo "  [4/5] Memory usage..."
gnuplot memory-usage.gnuplot

echo "  [5/5] Performance vs targets..."
gnuplot performance-vs-targets.gnuplot

echo ""
echo "✅ All charts generated successfully!"
echo ""
echo "Generated files:"
ls -lh *.png 2>/dev/null | awk '{print "  - " $9 " (" $5 ")"}'

echo ""
echo "View charts with: xdg-open *.png (Linux) or open *.png (macOS)"
