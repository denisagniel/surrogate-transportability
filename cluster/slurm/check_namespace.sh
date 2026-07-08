#!/bin/bash
echo "=== NAMESPACE content (tv_ball lines) ==="
grep "tv_ball" NAMESPACE

echo ""
echo "=== Checking which R files define these functions ==="
for func in sample_tv_ball gradient_correlation_analytical tv_ball_correlation_IF_adaptive; do
    echo "Searching for: $func"
    grep -l "^$func <-\|^${func} <- function" R/*.R 2>/dev/null || echo "  NOT FOUND"
done
