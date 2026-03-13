#!/bin/bash

# Submit all covariate shift validation scenarios to SLURM
# Each scenario runs 1000 replications as an array job

echo "Submitting covariate shift validation studies..."

# Create logs directory
mkdir -p logs

# Submit each scenario
for SCENARIO in small moderate large extreme; do
    echo "Submitting scenario: $SCENARIO"
    sbatch --export=SCENARIO=$SCENARIO sims/slurm/covariate_shift_validation.slurm
done

echo ""
echo "All jobs submitted. Monitor with: squeue -u \$USER"
echo "Check logs in: logs/covariate_shift_*.out"
