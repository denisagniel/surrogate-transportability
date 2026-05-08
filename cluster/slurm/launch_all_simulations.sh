#!/bin/bash
# Launch All Simulation Jobs
#
# Submits job arrays for all DGPs (dgp1, dgp2, dgp4, dgp5)
# 100 jobs per DGP × 4 DGPs = 400 jobs total
# Expected total runtime: ~40 minutes (parallel execution)

set -e

echo "========================================="
echo "Launching Surrogate Validation Simulations"
echo "========================================="
echo ""

# Create log directory
mkdir -p cluster/slurm/logs

# DGP list
DGPS=("dgp1" "dgp2" "dgp4" "dgp5")

# Submit jobs for each DGP
JOB_IDS=()

for DGP in "${DGPS[@]}"; do
    echo "Submitting jobs for ${DGP}..."

    JOB_ID=$(sbatch --parsable --export=DGP_ID=${DGP} cluster/slurm/run_simulations.slurm)

    if [ $? -eq 0 ]; then
        JOB_IDS+=("${DGP}:${JOB_ID}")
        echo "  Job ID: ${JOB_ID} (100 array tasks)"
    else
        echo "  ERROR: Failed to submit ${DGP}"
        exit 1
    fi

    echo ""
done

echo "========================================="
echo "All jobs submitted successfully!"
echo ""
echo "Job IDs:"
for JOB_INFO in "${JOB_IDS[@]}"; do
    echo "  ${JOB_INFO}"
done
echo ""
echo "Total: 400 jobs (4 DGPs × 100 batches)"
echo "Expected completion: ~40 minutes"
echo ""
echo "Monitor progress:"
echo "  bash cluster/slurm/check_progress.sh"
echo ""
echo "========================================="
