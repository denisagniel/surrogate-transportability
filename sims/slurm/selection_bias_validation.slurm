#!/bin/bash
#SBATCH --job-name=sel_bias
#SBATCH --output=logs/selection_bias_%A_%a.out
#SBATCH --error=logs/selection_bias_%A_%a.err
#SBATCH --array=1-1000
#SBATCH --cpus-per-task=1
#SBATCH --mem=6G
#SBATCH --time=00:45:00
#SBATCH --partition=short

# Selection Bias Validation Study
# Run as: sbatch --export=SCENARIO=weak_outcome sims/slurm/selection_bias_validation.slurm
#
# SCENARIO must be one of: weak_outcome, moderate_outcome, strong_outcome, moderate_responders
# Runs 1000 replications for the specified scenario
#
# O2-specific configuration:
# - partition=short: 12 hour limit, faster scheduling
# - mem=6G: Conservative for O2 environment
# - R/4.5.2: Latest stable R version on O2

# Check that SCENARIO is set
if [ -z "$SCENARIO" ]; then
    echo "ERROR: SCENARIO environment variable not set"
    echo "Usage: sbatch --export=SCENARIO=weak_outcome sims/slurm/selection_bias_validation.slurm"
    exit 1
fi

# Load R module (O2-specific)
module load R/4.5.2

# Verify R loaded successfully
if ! command -v R &> /dev/null; then
    echo "ERROR: R module failed to load"
    exit 1
fi

# Navigate to project directory
cd $SLURM_SUBMIT_DIR

# Create output directory if needed
mkdir -p sims/results/reps/selection_bias

# Run single replication
Rscript sims/scripts/run_single_replication.R \
  --study-type selection_bias \
  --scenario $SCENARIO \
  --replication $SLURM_ARRAY_TASK_ID \
  --output-dir sims/results/reps/selection_bias \
  --n-baseline 1000 \
  --n-true-studies 500 \
  --n-baseline-resamples 100 \
  --n-bootstrap 100 \
  --n-mc-draws 50

# Exit with script's exit code
exit $?
