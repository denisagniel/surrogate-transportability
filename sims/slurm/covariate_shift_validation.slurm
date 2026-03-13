#!/bin/bash
#SBATCH --job-name=cov_shift
#SBATCH --output=logs/covariate_shift_%A_%a.out
#SBATCH --error=logs/covariate_shift_%A_%a.err
#SBATCH --array=1-1000
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:30:00
#SBATCH --partition=short

# Covariate Shift Validation Study
# Run as: sbatch --export=SCENARIO=small sims/slurm/covariate_shift_validation.slurm
#
# SCENARIO must be one of: small, moderate, large, extreme
# Runs 1000 replications for the specified scenario

# Check that SCENARIO is set
if [ -z "$SCENARIO" ]; then
    echo "ERROR: SCENARIO environment variable not set"
    echo "Usage: sbatch --export=SCENARIO=small sims/slurm/covariate_shift_validation.slurm"
    exit 1
fi

# Load R module (adjust for your cluster)
module load R/4.5.0

# Navigate to project directory
cd $SLURM_SUBMIT_DIR

# Create output directory if needed
mkdir -p sims/results/reps/covariate_shift

# Run single replication
Rscript sims/scripts/run_single_replication.R \
  --study-type covariate_shift \
  --scenario $SCENARIO \
  --replication $SLURM_ARRAY_TASK_ID \
  --output-dir sims/results/reps/covariate_shift \
  --n-baseline 1000 \
  --n-true-studies 500 \
  --n-baseline-resamples 100 \
  --n-bootstrap 100 \
  --n-mc-draws 50

# Exit with script's exit code
exit $?
