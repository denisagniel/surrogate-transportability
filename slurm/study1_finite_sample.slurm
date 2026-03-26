#!/bin/bash
#SBATCH --job-name=study1_finite_sample
#SBATCH --output=logs/study1_%j.out
#SBATCH --error=logs/study1_%j.err
#SBATCH --partition=short
#SBATCH --time=08:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=9
#SBATCH --mem=32G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your.email@example.com

# Study 1: Finite Sample Performance
# Validates nominal coverage (95%), low bias, consistency
# Total: 24,000 replications (500 reps × 48 settings)
# Expected runtime: 6-8 hours with 9 cores

echo "=========================================="
echo "Study 1: Finite Sample Performance"
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

# Install required packages if not already installed
Rscript -e "
if (!require('devtools')) install.packages('devtools', repos='http://cran.rstudio.com/')
if (!require('tidyverse')) install.packages('tidyverse', repos='http://cran.rstudio.com/')
if (!require('furrr')) install.packages('furrr', repos='http://cran.rstudio.com/')
if (!require('progressr')) install.packages('progressr', repos='http://cran.rstudio.com/')
if (!require('here')) install.packages('here', repos='http://cran.rstudio.com/')
"

echo ""
echo "Packages loaded. Starting simulation..."
echo ""

# Run Study 1
N_REPS=500 N_CORES=9 Rscript sims/scripts/01_finite_sample_performance.R

# Check exit status
if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "Study 1 COMPLETED SUCCESSFULLY"
    echo "End time: $(date)"
    echo "=========================================="

    # List output files
    echo ""
    echo "Output files created:"
    ls -lh sims/results/finite_sample*

    # Print summary statistics
    echo ""
    echo "Result file sizes:"
    du -h sims/results/finite_sample_results.rds

else
    echo ""
    echo "=========================================="
    echo "Study 1 FAILED"
    echo "Exit code: $?"
    echo "End time: $(date)"
    echo "=========================================="
    exit 1
fi
