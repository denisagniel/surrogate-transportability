#!/bin/bash
#SBATCH --job-name=study1_quick
#SBATCH --output=slurm/logs/study1_quick_%A_%a.out
#SBATCH --error=slurm/logs/study1_quick_%A_%a.err
#SBATCH --partition=short
#SBATCH --array=1-8
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your.email@example.com

# Study 1 Quick Test - Job Array
# 8 parameter combinations (2 n × 2 scenarios × 2 lambda)
# Each task runs 20 replications
# Total: 160 replications (~5-10 minutes)

echo "=========================================="
echo "Study 1 Quick Test - Task $SLURM_ARRAY_TASK_ID of 8"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "Start time: $(date)"
echo "=========================================="
echo ""

# Load modules
module load gcc/14.2.0
module load R/4.4.2

# Set up environment
export R_LIBS_USER=$HOME/R/library
export N_REPS=20

# Change to project directory
cd $SLURM_SUBMIT_DIR

# Run this task
echo "Running task $SLURM_ARRAY_TASK_ID with $N_REPS replications (QUICK TEST)..."
Rscript sims/scripts/array/01_finite_sample_single_task.R

# Check exit status
if [ $? -eq 0 ]; then
    echo ""
    echo "Task $SLURM_ARRAY_TASK_ID COMPLETED"
    echo "End time: $(date)"
else
    echo ""
    echo "Task $SLURM_ARRAY_TASK_ID FAILED"
    exit 1
fi
