#!/bin/bash
#SBATCH --job-name=sample_size_test
#SBATCH --output=slurm_logs/sample_size_%A_%a.out
#SBATCH --error=slurm_logs/sample_size_%A_%a.err
#SBATCH --array=1-200
#SBATCH --time=01:00:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1

# SLURM array job for sample size effect test
# 4 sample sizes × 50 reps = 200 total jobs
# Each job runs one replication for one sample size

# Setup
module load R/4.3.0  # Adjust to your cluster's R module

cd /Users/dagniel/RAND/rprojects/surrogates/surrogate-transportability

# Create output directory
OUTPUT_DIR="test_sample_size_results"
mkdir -p "$OUTPUT_DIR"
mkdir -p slurm_logs

# Array mapping: task_id -> (sample_size, rep)
# Tasks 1-50: n=250, reps 1-50
# Tasks 51-100: n=500, reps 1-50
# Tasks 101-150: n=1000, reps 1-50
# Tasks 151-200: n=2000, reps 1-50

TASK_ID=$SLURM_ARRAY_TASK_ID

if [ $TASK_ID -le 50 ]; then
  N=250
  REP=$TASK_ID
elif [ $TASK_ID -le 100 ]; then
  N=500
  REP=$((TASK_ID - 50))
elif [ $TASK_ID -le 150 ]; then
  N=1000
  REP=$((TASK_ID - 100))
else
  N=2000
  REP=$((TASK_ID - 150))
fi

echo "========================================"
echo "SLURM Task: $TASK_ID"
echo "Sample size: n=$N"
echo "Replication: $REP"
echo "========================================"

# Run single replication
Rscript test_sample_size_effect_single.R "$N" "$REP" "$OUTPUT_DIR"

echo "Task $TASK_ID complete"
