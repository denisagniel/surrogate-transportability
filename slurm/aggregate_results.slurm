#!/bin/bash
#SBATCH --job-name=aggregate
#SBATCH --output=slurm/logs/aggregate_%j.out
#SBATCH --error=slurm/logs/aggregate_%j.err
#SBATCH --partition=short
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your.email@example.com

# Aggregate results from array jobs
# Run this after all array tasks complete

echo "=========================================="
echo "Aggregating Results"
echo "Job ID: $SLURM_JOB_ID"
echo "Start time: $(date)"
echo "=========================================="
echo ""

# Load modules
module load gcc/14.2.0
module load R/4.4.2

# Set up environment
export R_LIBS_USER=$HOME/R/library

# Change to project directory
cd $SLURM_SUBMIT_DIR

# Aggregate Study 1
if [ -d "sims/results/study1_array" ]; then
    echo "Aggregating Study 1 results..."
    Rscript sims/scripts/array/aggregate_study1.R
    echo ""
fi

# Aggregate Study 2
if [ -d "sims/results/study2_array" ]; then
    echo "Aggregating Study 2 results..."
    Rscript sims/scripts/array/aggregate_study2.R
    echo ""
fi

echo "=========================================="
echo "Aggregation Complete"
echo "End time: $(date)"
echo "=========================================="
