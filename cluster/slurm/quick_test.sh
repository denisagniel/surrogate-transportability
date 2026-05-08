#!/bin/bash
# Quick Test: Single Batch with 2 Reps
#
# Tests infrastructure end-to-end in ~10-12 minutes:
# - Package loading
# - Data generation
# - Adaptive M estimation (2 reps)
# - Result saving
# - File structure
#
# Run this BEFORE launching full simulation study

set -e

echo "========================================="
echo "Quick Test: Surrogate Validation Infrastructure"
echo "========================================="
echo ""

# Create test output directory
TEST_DIR="cluster/slurm/test_output"
mkdir -p ${TEST_DIR}

echo "Testing single batch (2 reps, dgp1)..."
echo "Expected time: ~10-12 minutes"
echo ""

# Run test
time Rscript cluster/slurm/run_single_replication.R \
    --dgp dgp1 \
    --batch 1 \
    --reps-per-batch 2 \
    --config cluster/config/dgp_specifications.yaml \
    --output-dir ${TEST_DIR}

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Test failed!"
    exit 1
fi

echo ""
echo "========================================="
echo "Test PASSED!"
echo "========================================="
echo ""

# Check output
if [ -f "${TEST_DIR}/batch_001.rds" ]; then
    echo "✓ Output file created: ${TEST_DIR}/batch_001.rds"

    # Show structure
    echo ""
    echo "Result structure:"
    Rscript -e "
    result <- readRDS('${TEST_DIR}/batch_001.rds')
    cat('  DGP:', result\$dgp_id, '\n')
    cat('  Batch:', result\$batch_number, '\n')
    cat('  Reps:', length(result\$results), '\n')
    cat('  Time:', sprintf('%.1f', result\$batch_time_minutes), 'minutes\n')
    cat('\n  First rep results:\n')
    rep1 <- result\$results[[1]]
    cat('    rho_hat:', sprintf('%.4f', rep1\$rho_hat), '\n')
    cat('    M_final:', rep1\$M_final, '\n')
    cat('    converged:', rep1\$converged, '\n')
    cat('    time:', sprintf('%.1f', rep1\$elapsed_time), 'seconds\n')
    "
else
    echo "ERROR: Output file not found!"
    exit 1
fi

echo ""
echo "========================================="
echo "Infrastructure is ready for cluster deployment!"
echo ""
echo "Next steps:"
echo "  1. git add -A && git commit -m 'Add cluster infrastructure'"
echo "  2. git push"
echo "  3. On O2: git pull"
echo "  4. On O2: bash cluster/slurm/launch_all_simulations.sh"
echo "========================================="
