#!/bin/bash
#SBATCH --job-name=surrogate_validation
#SBATCH --output=cluster/logs/%A_%a.out
#SBATCH --error=cluster/logs/%A_%a.err
#SBATCH --array=1-2000
#SBATCH --time=02:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH --partition=general

# Surrogate Transportability Validation: Cluster Simulations
#
# Job array: 2000 jobs total
#   - Jobs 1-1000: DGP 1
#   - Jobs 1001-2000: DGP 2
#
# Each job runs one replication with adaptive M
# Expected time: ~5-6 minutes per job

echo "========================================="
echo "Surrogate Validation Cluster Job"
echo "========================================="
echo "Job ID: ${SLURM_JOB_ID}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Node: ${SLURM_NODENAME}"
echo "Start time: $(date)"
echo ""

# Load R module (adjust for your cluster)
module load R/4.3.0 || module load r/4.3.0

# Navigate to project directory
cd $SLURM_SUBMIT_DIR

# Determine DGP and replication number
if [ ${SLURM_ARRAY_TASK_ID} -le 1000 ]; then
    DGP="dgp1"
    REP=${SLURM_ARRAY_TASK_ID}
else
    DGP="dgp2"
    REP=$((${SLURM_ARRAY_TASK_ID} - 1000))
fi

echo "DGP: ${DGP}"
echo "Replication: ${REP}"
echo ""

# Run the simulation
Rscript cluster/scripts/run_single_rep.R \
    ${DGP} \
    ${REP} \
    cluster/config/dgp_specifications.yaml

EXIT_CODE=$?

echo ""
echo "Exit code: ${EXIT_CODE}"
echo "End time: $(date)"
echo "========================================="

exit ${EXIT_CODE}
