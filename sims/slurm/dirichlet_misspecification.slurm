#!/bin/bash
#SBATCH --job-name=dirichlet
#SBATCH --output=logs/dirichlet_%A_%a.out
#SBATCH --error=logs/dirichlet_%A_%a.err
#SBATCH --array=1-1000
#SBATCH --cpus-per-task=1
#SBATCH --mem=6G
#SBATCH --time=00:45:00
#SBATCH --partition=short

# Dirichlet Misspecification Validation Study
# Run as: sbatch --export=SCENARIO=sparse sims/slurm/dirichlet_misspecification.slurm
#
# SCENARIO must be one of: very_sparse, sparse, uniform, concentrated, highly_concentrated, very_concentrated
# Runs 1000 replications for the specified scenario
#
# O2-specific configuration:
# - partition=short: 12 hour limit, faster scheduling
# - mem=6G: Conservative for O2 environment
# - R/4.5.2: Latest stable R version on O2

# Check that SCENARIO is set
if [ -z "$SCENARIO" ]; then
    echo "ERROR: SCENARIO environment variable not set"
    echo "Usage: sbatch --export=SCENARIO=sparse sims/slurm/dirichlet_misspecification.slurm"
    exit 1
fi

# Load gcc first (required for R on O2)
module load gcc/9.2.0 2>/dev/null || module load gcc 2>/dev/null || true

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

# Create output directory if needed
mkdir -p sims/results/reps/dirichlet_misspec

# Run single replication with fixed lambda=0.2
Rscript sims/scripts/run_single_replication.R \
  --study-type dirichlet_misspec \
  --scenario $SCENARIO \
  --replication $SLURM_ARRAY_TASK_ID \
  --output-dir sims/results/reps/dirichlet_misspec \
  --lambda 0.2 \
  --n-baseline 1000 \
  --n-true-studies 500 \
  --n-baseline-resamples 100 \
  --n-bootstrap 100 \
  --n-mc-draws 50

# Exit with script's exit code
exit $?
