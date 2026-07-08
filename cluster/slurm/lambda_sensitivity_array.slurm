#!/bin/bash
#SBATCH --job-name=lambda_sens
#SBATCH --output=cluster/slurm/logs/%x_%A_%a.out
#SBATCH --error=cluster/slurm/logs/%x_%A_%a.err
#SBATCH --array=1-20
#SBATCH --time=02:00:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#SBATCH --partition=short

# Lambda Sensitivity Analysis: Cluster Simulations
#
# Job array configuration:
#   - 20 jobs total: 5 lambda values × 4 DGPs
#   - 1000 reps per job (match main study quality)
#   - Expected runtime: 1.5 hours per job
#
# Array task mapping:
#   Task 1-5:   lambda=0.1,0.2,0.3,0.4,0.5 × dgp1
#   Task 6-10:  lambda=0.1,0.2,0.3,0.4,0.5 × dgp2
#   Task 11-15: lambda=0.1,0.2,0.3,0.4,0.5 × dgp4
#   Task 16-20: lambda=0.1,0.2,0.3,0.4,0.5 × dgp5
#
# Usage:
#   sbatch cluster/slurm/lambda_sensitivity_array.slurm

echo "========================================="
echo "Lambda Sensitivity Analysis"
echo "========================================="
echo "Job ID: ${SLURM_JOB_ID}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Node: ${SLURM_NODENAME}"
echo "Start time: $(date)"
echo ""

# Map array task ID to (lambda, DGP) combination
LAMBDAS=(0.1 0.2 0.3 0.4 0.5)
DGPS=(dgp1 dgp2 dgp4 dgp5)

# Calculate indices (task IDs 1-20)
TASK_IDX=$((SLURM_ARRAY_TASK_ID - 1))
DGP_IDX=$((TASK_IDX / 5))
LAMBDA_IDX=$((TASK_IDX % 5))

LAMBDA=${LAMBDAS[$LAMBDA_IDX]}
DGP_ID=${DGPS[$DGP_IDX]}

echo "Configuration:"
echo "  Lambda: ${LAMBDA}"
echo "  DGP: ${DGP_ID}"
echo "  Replications: 1000"
echo ""

# Load modules (O2 defaults)
module load gcc/14.2.0
module load R/4.4.2

# Navigate to project directory
cd $SLURM_SUBMIT_DIR

# Setup scratch directory
SCRATCH_DIR="/n/scratch/users/${USER:0:1}/${USER}/lambda_sens_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
mkdir -p ${SCRATCH_DIR}

echo "Working directory: $(pwd)"
echo "Scratch directory: ${SCRATCH_DIR}"
echo ""

# Run the lambda sensitivity study
Rscript sims/scripts/lambda_sensitivity_study.R \
    --lambda ${LAMBDA} \
    --dgp ${DGP_ID} \
    --n-reps 1000 \
    --config cluster/config/dgp_specifications.yaml \
    --output-dir ${SCRATCH_DIR}

EXIT_CODE=$?

# Copy results to permanent storage
if [ ${EXIT_CODE} -eq 0 ]; then
    echo ""
    echo "Copying results to permanent storage..."
    mkdir -p cluster/results/lambda_sensitivity
    cp ${SCRATCH_DIR}/lambda_${LAMBDA}_${DGP_ID}.rds \
       cluster/results/lambda_sensitivity/
    echo "Results saved to cluster/results/lambda_sensitivity/"
fi

# Cleanup scratch
rm -rf ${SCRATCH_DIR}

echo ""
echo "Exit code: ${EXIT_CODE}"
echo "End time: $(date)"
echo "========================================="

exit ${EXIT_CODE}
