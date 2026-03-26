#!/bin/bash
#SBATCH --job-name=study2_array
#SBATCH --output=slurm/logs/study2_array_%A_%a.out
#SBATCH --error=slurm/logs/study2_array_%A_%a.err
#SBATCH --partition=short
#SBATCH --array=1-21
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your.email@example.com

# Study 2: Stress Testing - Job Array
# 21 stress conditions across 5 stress types
# Each task runs 500 replications independently
# Total: 10,500 replications

echo "=========================================="
echo "Study 2 Array - Task $SLURM_ARRAY_TASK_ID of 21"
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
Rscript sims/scripts/array/02_stress_testing_single_task.R

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
