#!/bin/bash
#SBATCH --job-name=study1_array
#SBATCH --output=slurm/logs/study1_array_%A_%a.out
#SBATCH --error=slurm/logs/study1_array_%A_%a.err
#SBATCH --partition=short
#SBATCH --array=1-48
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your.email@example.com

# Study 1: Finite Sample Performance - Job Array
# 48 parameter combinations (4 n × 3 scenarios × 4 lambda)
# Each task runs 500 replications independently
# Total: 24,000 replications

echo "=========================================="
echo "Study 1 Array - Task $SLURM_ARRAY_TASK_ID of 48"
echo "Job ID: $SLURM_JOB_ID"
echo "Array Job ID: $SLURM_ARRAY_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "Start time: $(date)"
echo "=========================================="
echo ""

# Load modules
module load gcc/14.2.0
module load R/4.4.2

# Set up environment
export R_LIBS_USER=$HOME/R/library
export N_REPS=500

# Change to project directory
cd $SLURM_SUBMIT_DIR

# Run this task
echo "Running task $SLURM_ARRAY_TASK_ID with $N_REPS replications..."
Rscript sims/scripts/array/01_finite_sample_single_task.R

# Check exit status
if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "Task $SLURM_ARRAY_TASK_ID COMPLETED"
    echo "End time: $(date)"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "Task $SLURM_ARRAY_TASK_ID FAILED"
    echo "End time: $(date)"
    echo "=========================================="
    exit 1
fi
