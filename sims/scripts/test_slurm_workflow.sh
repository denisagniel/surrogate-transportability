#!/bin/bash

# Test SLURM workflow locally before submitting to cluster
# Runs a few replications, then aggregates results

set -e  # Exit on error

echo "================================================================"
echo "TESTING SLURM WORKFLOW LOCALLY"
echo "================================================================"
echo ""

# Clean up any existing test results
rm -rf sims/results/reps/test_covariate_shift
mkdir -p sims/results/reps/test_covariate_shift

# Run 5 replications for small scenario (reduced parameters for speed)
echo "Running 5 test replications..."
for REP in 1 2 3 4 5; do
    echo "  Replication $REP/5..."
    Rscript sims/scripts/run_single_replication.R \
      --study-type covariate_shift \
      --scenario small \
      --replication $REP \
      --output-dir sims/results/reps/test_covariate_shift \
      --n-baseline 300 \
      --n-true-studies 50 \
      --n-baseline-resamples 10 \
      --n-bootstrap 20 \
      --n-mc-draws 10 \
      > /dev/null 2>&1
done

echo ""
echo "All replications complete. Aggregating results..."
echo ""

# Aggregate results
Rscript sims/scripts/aggregate_results.R \
  --study-type covariate_shift \
  --input-dir sims/results/reps/test_covariate_shift \
  --output-dir sims/results/test_output

echo ""
echo "================================================================"
echo "TEST COMPLETE"
echo "================================================================"
echo ""
echo "Results saved to: sims/results/test_output/"
echo ""
echo "Check outputs:"
echo "  - covariate_shift_validation_summary.csv"
echo "  - covariate_shift_coverage_by_scenario.png"
echo "  - covariate_shift_ci_coverage_sample.png"
echo "  - covariate_shift_calibration.png"
echo ""
echo "If this works, you're ready to submit to SLURM with:"
echo "  bash sims/slurm/submit_all_covariate_shift.sh"
echo ""
