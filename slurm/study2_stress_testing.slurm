#!/bin/bash
#SBATCH --job-name=study2_stress_test
#SBATCH --output=slurm/logs/study2_%j.out
#SBATCH --error=slurm/logs/study2_%j.err
#SBATCH --partition=short
#SBATCH --time=06:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=9
#SBATCH --mem=32G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your.email@example.com

# Study 2: Stress Testing
# Finds limits - where methods weaken or break
# Total: 10,500 replications (500 reps × 21 conditions)
# Expected runtime: 4-6 hours with 9 cores

echo "=========================================="
echo "Study 2: Stress Testing"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "Start time: $(date)"
echo "=========================================="
echo ""

# Load R module
module load gcc/14.2.0
module load R/4.4.2

# Set up environment
export R_LIBS_USER=$HOME/R/library
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Change to project directory
cd $SLURM_SUBMIT_DIR

echo ""
echo "Starting simulation..."
echo ""

# Run Study 2
N_REPS=500 N_CORES=9 Rscript sims/scripts/02_stress_testing.R

# Check exit status
if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "Study 2 COMPLETED SUCCESSFULLY"
    echo "End time: $(date)"
    echo "=========================================="

    # List output files
    echo ""
    echo "Output files created:"
    ls -lh sims/results/stress_test*

    # Print summary statistics
    echo ""
    echo "Result file sizes:"
    du -h sims/results/stress_test_results.rds

else
    echo ""
    echo "=========================================="
    echo "Study 2 FAILED"
    echo "Exit code: $?"
    echo "End time: $(date)"
    echo "=========================================="
    exit 1
fi
