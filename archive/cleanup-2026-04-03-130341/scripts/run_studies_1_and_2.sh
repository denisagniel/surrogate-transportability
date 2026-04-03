#!/bin/bash
# Run Studies 1 & 2 with Progress Monitoring
#
# Usage:
#   bash run_studies_1_and_2.sh [quick|reduced|full]
#
# Modes:
#   quick   - 20 reps, ~15 minutes total
#   reduced - 100 reps, ~3-5 hours total (RECOMMENDED)
#   full    - 500 reps, ~12-18 hours total

MODE="${1:-reduced}"

echo "=================================="
echo "Running Studies 1 & 2: ${MODE} mode"
echo "=================================="
echo ""

# Check for orphaned workers
ORPHANS=$(ps aux | grep "parallelly.parent" | grep -v grep | wc -l)
if [ "$ORPHANS" -gt 0 ]; then
    echo "⚠️  Warning: $ORPHANS orphaned R workers found"
    echo "   Kill them first: pkill -f parallelly"
    exit 1
fi

# Set parameters based on mode
case "$MODE" in
    quick)
        N_REPS=20
        N_CORES=1
        RUNTIME="~15 minutes"
        ;;
    reduced)
        N_REPS=100
        N_CORES=3
        RUNTIME="~3-5 hours"
        ;;
    full)
        N_REPS=500
        N_CORES=9
        RUNTIME="~12-18 hours"
        ;;
    *)
        echo "Unknown mode: $MODE"
        echo "Use: quick, reduced, or full"
        exit 1
        ;;
esac

echo "Configuration:"
echo "  Replications: $N_REPS per setting"
echo "  Cores: $N_CORES"
echo "  Estimated runtime: $RUNTIME"
echo ""
echo "Study 1: 48 settings × $N_REPS reps = $(($N_REPS * 48)) total"
echo "Study 2: 21 conditions × $N_REPS reps = $(($N_REPS * 21)) total"
echo ""

# Create results directory
mkdir -p sims/results

# Study 1
echo "=== Starting Study 1: Finite Sample Performance ==="
echo ""
N_REPS=$N_REPS N_CORES=$N_CORES Rscript sims/scripts/01_finite_sample_performance.R \
    > sims/results/study1_${MODE}.log 2>&1 &
STUDY1_PID=$!
echo "Study 1 PID: $STUDY1_PID"
echo "Monitor: tail -f sims/results/study1_${MODE}.log"
echo ""

# Wait a bit for Study 1 to start
sleep 10

# Study 2
echo "=== Starting Study 2: Stress Testing ==="
echo ""
N_REPS=$N_REPS N_CORES=$N_CORES Rscript sims/scripts/02_stress_testing.R \
    > sims/results/study2_${MODE}.log 2>&1 &
STUDY2_PID=$!
echo "Study 2 PID: $STUDY2_PID"
echo "Monitor: tail -f sims/results/study2_${MODE}.log"
echo ""

# Create monitoring script
cat > sims/results/monitor_studies.sh << 'EOF'
#!/bin/bash
clear
echo "=== Study 1 & 2 Monitor ==="
echo ""

# Study 1
if ps -p $1 > /dev/null 2>&1; then
    echo "Study 1 (PID $1): Running"
    ELAPSED=$(ps -p $1 -o etime= | tr -d ' ')
    echo "  Elapsed: $ELAPSED"
    echo "  Last progress:"
    tail -3 sims/results/study1_*.log 2>/dev/null | grep "Rep" | tail -1
else
    echo "Study 1 (PID $1): Complete or stopped"
fi

echo ""

# Study 2
if ps -p $2 > /dev/null 2>&1; then
    echo "Study 2 (PID $2): Running"
    ELAPSED=$(ps -p $2 -o etime= | tr -d ' ')
    echo "  Elapsed: $ELAPSED"
    echo "  Last progress:"
    tail -3 sims/results/study2_*.log 2>/dev/null | grep "Rep" | tail -1
else
    echo "Study 2 (PID $2): Complete or stopped"
fi

echo ""
echo "=== R Workers ==="
N_WORKERS=$(ps aux | grep "parallelly.parent" | grep -v grep | wc -l)
echo "Active workers: $N_WORKERS"

echo ""
echo "=== CPU Usage ===""
ps aux | grep "/Library/Frameworks/R.framework" | grep -v grep | \
    awk '{sum+=$3} END {print "Total R CPU: " sum "%"}'

echo ""
echo "Press Ctrl+C to stop monitoring"
echo "To kill studies: kill $1 $2"
EOF

chmod +x sims/results/monitor_studies.sh

echo "=== Monitoring Commands ==="
echo ""
echo "Watch progress (auto-refresh every 30 sec):"
echo "  watch -n 30 bash sims/results/monitor_studies.sh $STUDY1_PID $STUDY2_PID"
echo ""
echo "Check logs:"
echo "  tail -f sims/results/study1_${MODE}.log"
echo "  tail -f sims/results/study2_${MODE}.log"
echo ""
echo "Stop studies:"
echo "  kill $STUDY1_PID $STUDY2_PID"
echo ""
echo "Check results:"
echo "  ls -lh sims/results/finite_sample_results.rds"
echo "  ls -lh sims/results/stress_test_results.rds"
echo ""

# Wait for completion (optional)
if [ "$MODE" = "quick" ]; then
    echo "Waiting for studies to complete..."
    wait $STUDY1_PID
    wait $STUDY2_PID
    echo ""
    echo "=== Studies Complete ==="
    ls -lh sims/results/*.rds
fi
