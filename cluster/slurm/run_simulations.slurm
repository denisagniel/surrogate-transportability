#!/bin/bash
#SBATCH --job-name=surrogate_val
#SBATCH --output=cluster/slurm/logs/%x_%A_%a.out
#SBATCH --error=cluster/slurm/logs/%x_%A_%a.err
#SBATCH --array=1-100
#SBATCH --time=02:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH --partition=short

# Surrogate Transportability Validation: Cluster Simulations
#
# Job array configuration:
#   - 100 jobs per DGP (10 reps per job, 1000 reps total per DGP)
#   - Must be launched separately for each DGP (dgp1, dgp2, dgp4)
#   - Expected runtime: 50-60 minutes per job
#
# Usage:
#   sbatch --export=DGP_ID=dgp1 cluster/slurm/run_simulations.slurm
#   sbatch --export=DGP_ID=dgp2 cluster/slurm/run_simulations.slurm
#   sbatch --export=DGP_ID=dgp4 cluster/slurm/run_simulations.slurm

echo "========================================="
echo "Surrogate Validation Cluster Job"
echo "========================================="
echo "Job ID: ${SLURM_JOB_ID}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "DGP: ${DGP_ID}"
echo "Node: ${SLURM_NODENAME}"
echo "Start time: $(date)"
echo ""

# Validate DGP_ID
if [ -z "${DGP_ID}" ]; then
    echo "ERROR: DGP_ID not set. Use --export=DGP_ID=dgp1"
    exit 1
fi

# Load modules (O2 defaults)
module load gcc/14.2.0
module load R/4.4.2

# Navigate to project directory
cd $SLURM_SUBMIT_DIR

# Setup scratch directory
SCRATCH_DIR="/n/scratch/users/${USER:0:1}/${USER}/surrogate_${SLURM_JOB_ID}"
mkdir -p ${SCRATCH_DIR}

echo "Working directory: $(pwd)"
echo "Scratch directory: ${SCRATCH_DIR}"
echo ""

# Run the batch
Rscript cluster/slurm/run_single_replication.R \
    --dgp ${DGP_ID} \
    --batch ${SLURM_ARRAY_TASK_ID} \
    --reps-per-batch 10 \
    --config cluster/config/dgp_specifications.yaml \
    --output-dir ${SCRATCH_DIR}/${DGP_ID}

EXIT_CODE=$?

# Copy results to permanent storage
if [ ${EXIT_CODE} -eq 0 ]; then
    echo ""
    echo "Copying results to permanent storage..."
    mkdir -p cluster/results/${DGP_ID}
    cp ${SCRATCH_DIR}/${DGP_ID}/batch_$(printf "%03d" ${SLURM_ARRAY_TASK_ID}).rds \
       cluster/results/${DGP_ID}/
    echo "Results saved to cluster/results/${DGP_ID}/"
fi

# Cleanup scratch
rm -rf ${SCRATCH_DIR}

echo ""
echo "Exit code: ${EXIT_CODE}"
echo "End time: $(date)"
echo "========================================="

exit ${EXIT_CODE}
