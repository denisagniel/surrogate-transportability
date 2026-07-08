#!/bin/bash
echo "=== Checking R/tv_ball files ==="
ls -lh R/tv_ball*.R

echo ""
echo "=== Checking if adaptive file exists ==="
if [ -f "R/tv_ball_correlation_IF_adaptive.R" ]; then
    echo "✓ R/tv_ball_correlation_IF_adaptive.R exists"
    echo "First 5 lines:"
    head -5 R/tv_ball_correlation_IF_adaptive.R
else
    echo "✗ R/tv_ball_correlation_IF_adaptive.R NOT FOUND"
fi

echo ""
echo "=== Checking NAMESPACE ==="
grep "tv_ball" NAMESPACE
