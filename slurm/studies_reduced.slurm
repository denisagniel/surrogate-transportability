#!/bin/bash
#SBATCH --job-name=studies_reduced
#SBATCH --output=slurm/logs/studies_reduced_%j.out
#SBATCH --error=slurm/logs/studies_reduced_%j.err
#SBATCH --partition=short
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=9
#SBATCH --mem=32G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your.email@example.com

# Studies 1 & 2: REDUCED VERSION (100 reps instead of 500)
# Faster validation while maintaining statistical validity
# Total: Study 1: 4,800 reps + Study 2: 2,100 reps = 6,900 total
# Expected runtime: 3-4 hours with 9 cores

echo "=========================================="
echo "Studies 1 & 2: REDUCED VERSION"
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

# Install packages if needed
echo "Checking R packages..."
Rscript -e "
if (!require('devtools')) install.packages('devtools', repos='http://cran.rstudio.com/')
if (!require('tidyverse')) install.packages('tidyverse', repos='http://cran.rstudio.com/')
if (!require('furrr')) install.packages('furrr', repos='http://cran.rstudio.com/')
if (!require('progressr')) install.packages('progressr', repos='http://cran.rstudio.com/')
if (!require('here')) install.packages('here', repos='http://cran.rstudio.com/')
"

# =============================================================================
# STUDY 1: Finite Sample Performance
# =============================================================================
echo ""
echo "=========================================="
echo "Starting Study 1 (100 reps per setting)"
echo "Start: $(date)"
echo "=========================================="
echo ""

N_REPS=100 N_CORES=9 Rscript sims/scripts/01_finite_sample_performance.R

if [ $? -ne 0 ]; then
    echo "ERROR: Study 1 failed"
    exit 1
fi

echo ""
echo "Study 1 complete: $(date)"
echo "Output: $(ls -lh sims/results/finite_sample_results.rds)"
echo ""

# =============================================================================
# STUDY 2: Stress Testing
# =============================================================================
echo ""
echo "=========================================="
echo "Starting Study 2 (100 reps per condition)"
echo "Start: $(date)"
echo "=========================================="
echo ""

N_REPS=100 N_CORES=9 Rscript sims/scripts/02_stress_testing.R

if [ $? -ne 0 ]; then
    echo "ERROR: Study 2 failed"
    exit 1
fi

echo ""
echo "Study 2 complete: $(date)"
echo "Output: $(ls -lh sims/results/stress_test_results.rds)"
echo ""

# =============================================================================
# SUMMARY
# =============================================================================
echo "=========================================="
echo "ALL STUDIES COMPLETED SUCCESSFULLY"
echo "End time: $(date)"
echo "=========================================="
echo ""
echo "Results created:"
ls -lh sims/results/finite_sample*
ls -lh sims/results/stress_test*

echo ""
echo "Total sizes:"
du -h sims/results/finite_sample_results.rds
du -h sims/results/stress_test_results.rds

echo ""
echo "Next step: Generate tables and figures"
echo "  Rscript sims/scripts/utils/create_tables.R"
echo "  Rscript sims/scripts/utils/create_figures.R"
