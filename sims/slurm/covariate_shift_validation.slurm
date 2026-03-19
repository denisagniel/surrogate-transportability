#!/bin/bash
#SBATCH --job-name=cov_shift
#SBATCH --output=logs/covariate_shift_%A_%a.out
#SBATCH --error=logs/covariate_shift_%A_%a.err
#SBATCH --array=1-1000
#SBATCH --cpus-per-task=1
#SBATCH --mem=6G
#SBATCH --time=00:45:00
#SBATCH --partition=short

# Covariate Shift Validation Study
# Run as: sbatch --export=SCENARIO=small sims/slurm/covariate_shift_validation.slurm
#
# SCENARIO must be one of: small, moderate, large, extreme
# Runs 1000 replications for the specified scenario
#
# O2-specific configuration:
# - partition=short: 12 hour limit, faster scheduling
# - mem=6G: Conservative for O2 environment
# - R/4.5.2: Latest stable R version on O2
# - array=1-500: Override with --array for testing (e.g., --array=1-10)

# Check that SCENARIO is set
if [ -z "$SCENARIO" ]; then
    echo "ERROR: SCENARIO environment variable not set"
    echo "Usage: sbatch --export=SCENARIO=small sims/slurm/covariate_shift_validation.slurm"
    exit 1
fi

# Load gcc first (required for R on O2)
module load gcc/14.2.0

# Load R module (O2-specific)
# Try multiple R versions in order of preference
for R_VERSION in R/4.4.2 R/4.4.1 R/4.3.1 R/4.2.2 R; do
    if module load $R_VERSION 2>/dev/null; then
        echo "Loaded $R_VERSION"
        break
    fi
done

# Verify R loaded successfully
if ! command -v R &> /dev/null; then
    echo "ERROR: R module failed to load"
    echo "Available versions: module spider R"
    exit 1
fi

# Navigate to project directory
cd $SLURM_SUBMIT_DIR

# Set output directory to scratch (not home directory!)
OUTPUT_DIR="/n/scratch3/users/${USER:0:1}/${USER}/surrogate-transportability/results/reps/covariate_shift"
mkdir -p "$OUTPUT_DIR"

# Run single replication
Rscript sims/scripts/run_single_replication.R \
  --study-type covariate_shift \
  --scenario $SCENARIO \
  --replication $SLURM_ARRAY_TASK_ID \
  --output-dir "$OUTPUT_DIR" \
  --n-baseline 1000 \
  --n-true-studies 500 \
  --n-baseline-resamples 100 \
  --n-bootstrap 100 \
  --n-mc-draws 50

# Exit with script's exit code
exit $?
