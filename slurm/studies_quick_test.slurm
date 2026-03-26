#!/bin/bash
#SBATCH --job-name=studies_quick_test
#SBATCH --output=logs/quick_test_%j.out
#SBATCH --error=logs/quick_test_%j.err
#SBATCH --partition=short
#SBATCH --time=00:30:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G

# Quick Test: Verify everything works before full run
# 20 reps per setting - completes in ~15 minutes
# USE THIS FIRST to catch errors early

echo "=========================================="
echo "Quick Test: Studies 1 & 2"
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

# Install packages
echo "Installing required R packages..."
Rscript -e "
if (!require('devtools')) install.packages('devtools', repos='http://cran.rstudio.com/')
if (!require('tidyverse')) install.packages('tidyverse', repos='http://cran.rstudio.com/')
if (!require('furrr')) install.packages('furrr', repos='http://cran.rstudio.com/')
if (!require('progressr')) install.packages('progressr', repos='http://cran.rstudio.com/')
if (!require('here')) install.packages('here', repos='http://cran.rstudio.com/')
devtools::load_all('package')
cat('✓ Packages loaded successfully\n')
"

if [ $? -ne 0 ]; then
    echo "ERROR: Package installation failed"
    exit 1
fi

# Test Study 1
echo ""
echo "Testing Study 1 (20 reps)..."
Rscript sims/scripts/01_finite_sample_performance_quick.R

if [ $? -ne 0 ]; then
    echo "ERROR: Study 1 quick test failed"
    exit 1
fi

echo "✓ Study 1 test passed"
echo ""

# Test Study 2
echo "Testing Study 2 (20 reps)..."
Rscript sims/scripts/02_stress_testing_quick.R

if [ $? -ne 0 ]; then
    echo "ERROR: Study 2 quick test failed"
    exit 1
fi

echo "✓ Study 2 test passed"
echo ""

# Verify outputs
echo "=========================================="
echo "QUICK TEST PASSED"
echo "End time: $(date)"
echo "=========================================="
echo ""
echo "Outputs created:"
ls -lh sims/results/finite_sample_results.rds 2>/dev/null || echo "  (Study 1 output)"
ls -lh sims/results/stress_test_results.rds 2>/dev/null || echo "  (Study 2 output)"

echo ""
echo "✓ Ready to run full studies"
echo "  Submit: sbatch slurm/studies_reduced.slurm"
echo "  or:     sbatch slurm/study1_finite_sample.slurm"
echo "          sbatch slurm/study2_stress_testing.slurm"
