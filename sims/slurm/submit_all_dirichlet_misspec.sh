#!/bin/bash

# Submit all Dirichlet misspecification validation scenarios to SLURM
# Each scenario runs 1000 replications as an array job

# Source O2 configuration
source sims/slurm/o2_config.sh

echo "=========================================="
echo "Submitting Dirichlet Misspecification"
echo "=========================================="
echo ""

# Create logs directory
mkdir -p logs

# Define scenarios
SCENARIOS=("very_sparse" "sparse" "uniform" "concentrated" "highly_concentrated" "very_concentrated")

# Submit each scenario
for SCENARIO in "${SCENARIOS[@]}"; do
    echo "Submitting scenario: $SCENARIO"
    JOB_ID=$(sbatch --export=SCENARIO=$SCENARIO --parsable sims/slurm/dirichlet_misspecification.slurm)
    echo "  Job ID: $JOB_ID"
    echo "  Array: 1-1000 replications"
    echo ""
done

echo "=========================================="
echo "All Dirichlet misspec jobs submitted"
echo "=========================================="
echo ""
echo "Monitor with:"
echo "  squeue -u \$USER"
echo "  watch -n 30 'squeue -u \$USER | wc -l'"
echo ""
echo "Check completeness:"
echo "  bash sims/slurm/check_completeness.sh dirichlet_misspec"
echo ""
echo "Logs in: logs/dirichlet_*.out"
