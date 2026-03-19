#!/bin/bash

# Submit all selection bias validation scenarios to SLURM
# Each scenario runs 1000 replications as an array job

# Source O2 configuration
source sims/slurm/o2_config.sh

echo "=========================================="
echo "Submitting Selection Bias Validation"
echo "=========================================="
echo ""

# Create logs directory
mkdir -p logs

# Define scenarios
SCENARIOS=("weak_outcome" "moderate_outcome" "strong_outcome" "moderate_responders")

# Submit each scenario
for SCENARIO in "${SCENARIOS[@]}"; do
    echo "Submitting scenario: $SCENARIO"
    JOB_ID=$(sbatch --export=SCENARIO=$SCENARIO --parsable sims/slurm/selection_bias_validation.slurm)
    echo "  Job ID: $JOB_ID"
    echo "  Array: 1-1000 replications"
    echo ""
done

echo "=========================================="
echo "All selection bias jobs submitted"
echo "=========================================="
echo ""
echo "Monitor with:"
echo "  squeue -u \$USER"
echo "  watch -n 30 'squeue -u \$USER | wc -l'"
echo ""
echo "Check completeness:"
echo "  bash sims/slurm/check_completeness.sh selection_bias"
echo ""
echo "Logs in: logs/selection_bias_*.out"
