#!/bin/bash
# Launch Lambda Sensitivity Analysis
#
# Submits array job with 20 tasks: 5 lambda values × 4 DGPs
# Each task runs 1000 replications for one (lambda, DGP) combination
# Total: 20,000 replications
#
# Expected runtime:
#   - Cluster (40 cores): ~1.5 hours (parallel execution)
#   - Local (8 cores): ~140 hours (sequential)

set -e

echo "========================================="
echo "Lambda Sensitivity Analysis"
echo "========================================="
echo ""
echo "Configuration:"
echo "  Lambda values: 0.1, 0.2, 0.3, 0.4, 0.5"
echo "  DGPs: dgp1, dgp2, dgp4, dgp5"
echo "  Replications per condition: 1000"
echo "  Total conditions: 5 × 4 = 20"
echo "  Total replications: 20,000"
echo ""

# Create log directory
mkdir -p cluster/slurm/logs

# Submit array job
echo "Submitting array job (20 tasks)..."

JOB_ID=$(sbatch --parsable cluster/slurm/lambda_sensitivity_array.slurm)

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "Job submitted successfully!"
    echo ""
    echo "Job ID: ${JOB_ID}"
    echo "Tasks: 20 (5 lambda × 4 DGPs)"
    echo "Expected completion: ~1.5 hours"
    echo ""
    echo "Monitor progress:"
    echo "  squeue -u ${USER} -j ${JOB_ID}"
    echo ""
    echo "Check logs:"
    echo "  ls -lt cluster/slurm/logs/lambda_sens_${JOB_ID}_*.out"
    echo ""
    echo "Results will be saved to:"
    echo "  cluster/results/lambda_sensitivity/"
    echo ""
    echo "After completion, generate Figure 3:"
    echo "  Rscript sims/scripts/generate_figure3_lambda_sensitivity.R"
    echo "========================================="
else
    echo "ERROR: Failed to submit job"
    exit 1
fi
