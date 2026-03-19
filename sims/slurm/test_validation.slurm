#!/bin/bash
#SBATCH --job-name=test_val
#SBATCH --output=logs/test_%A_%a.out
#SBATCH --error=logs/test_%A_%a.err
#SBATCH --array=1-10
#SBATCH --cpus-per-task=1
#SBATCH --mem=6G
#SBATCH --time=00:15:00
#SBATCH --partition=short

# Test Validation Study (Quick Verification)
# Run as: sbatch --export=STUDY_TYPE=covariate_shift,SCENARIO=small sims/slurm/test_validation.slurm
#
# STUDY_TYPE must be one of: covariate_shift, selection_bias, dirichlet_misspec
# SCENARIO must be appropriate for the study type
# Runs 10 replications with reduced parameters for quick testing
#
# Reduced parameters for testing:
# - n-baseline: 300 (vs 1000 in production)
# - n-bootstrap: 20 (vs 100 in production)
# - n-mc-draws: 10 (vs 50 in production)
# - Expected runtime: 3-5 minutes per replication

# Check that both STUDY_TYPE and SCENARIO are set
if [ -z "$STUDY_TYPE" ] || [ -z "$SCENARIO" ]; then
    echo "ERROR: STUDY_TYPE and SCENARIO environment variables must be set"
    echo "Usage: sbatch --export=STUDY_TYPE=covariate_shift,SCENARIO=small sims/slurm/test_validation.slurm"
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

# Set R library path to user library
export R_LIBS_USER="${HOME}/R/library"

# Navigate to project directory
cd $SLURM_SUBMIT_DIR

# Set output directory to scratch (not home directory!)
OUTPUT_DIR="/n/scratch/users/${USER:0:1}/${USER}/surrogate-transportability/results/reps/$STUDY_TYPE"
mkdir -p "$OUTPUT_DIR"

# Build Rscript command with conditional lambda parameter
RSCRIPT_CMD="Rscript sims/scripts/run_single_replication.R \
  --study-type $STUDY_TYPE \
  --scenario $SCENARIO \
  --replication $SLURM_ARRAY_TASK_ID \
  --output-dir \"$OUTPUT_DIR\" \
  --n-baseline 300 \
  --n-true-studies 100 \
  --n-baseline-resamples 50 \
  --n-bootstrap 20 \
  --n-mc-draws 10"

# Add lambda parameter for dirichlet_misspec study
if [ "$STUDY_TYPE" = "dirichlet_misspec" ]; then
    RSCRIPT_CMD="$RSCRIPT_CMD --lambda 0.2"
fi

# Run the command
eval $RSCRIPT_CMD

# Exit with script's exit code
exit $?
