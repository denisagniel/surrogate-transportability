#!/bin/bash
#SBATCH --job-name=aipw_robustness
#SBATCH --output=logs/aipw_%A_%a.out
#SBATCH --error=logs/aipw_%A_%a.err
#SBATCH --array=1-100%50
#SBATCH --partition=short
#SBATCH --time=12:00:00
#SBATCH --mem=8G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1

# ==============================================================================
# AIPW Robustness Study: SLURM Batch Script
# ==============================================================================
#
# Purpose: Run AIPW correlation estimation with noisy nuisances
# Each job handles REPS_PER_JOB replications of a single setting
#
# Usage: sbatch --export=SCENARIO=0,N=2000,ALPHA_1=0.3,... run_simulations.slurm
#
# Required environment variables (set by launch script):
#   SCENARIO    - Scenario number (0-3)
#   N           - Sample size
#   ALPHA_1     - Confounding strength
#   ALPHA_E     - Propensity convergence rate (scenarios 1,3)
#   ALPHA_MU    - Outcome convergence rate (scenarios 2,3)
#   C_E         - Propensity noise constant (scenarios 1,3)
#   C_MU        - Outcome noise constant (scenarios 2,3)
#   REPS_PER_JOB - Number of reps per job (default: 50)
#   TOTAL_REPS  - Total replications for this setting (default: 1000)
#
# ==============================================================================

# Load modules
module purge
module load gcc/14.2.0
module load R/4.4.2

# Configuration
REPS_PER_JOB=${REPS_PER_JOB:-50}  # Default: 50 reps per job
TOTAL_REPS=${TOTAL_REPS:-1000}     # Default: 1000 total reps

# Compute replication range for this array task
REP_START=$(( (SLURM_ARRAY_TASK_ID - 1) * REPS_PER_JOB + 1 ))
REP_END=$(( SLURM_ARRAY_TASK_ID * REPS_PER_JOB ))

# Don't exceed total reps
if [ $REP_END -gt $TOTAL_REPS ]; then
  REP_END=$TOTAL_REPS
fi

# Validate required environment variables
if [ -z "$SCENARIO" ] || [ -z "$N" ] || [ -z "$ALPHA_1" ]; then
  echo "Error: Missing required environment variables (SCENARIO, N, ALPHA_1)"
  exit 1
fi

# Set defaults for optional parameters based on scenario
if [ "$SCENARIO" -eq 0 ]; then
  # Oracle: no noise parameters needed
  ALPHA_E=${ALPHA_E:-0.5}
  ALPHA_MU=${ALPHA_MU:-0.5}
  C_E=${C_E:-1.0}
  C_MU=${C_MU:-1.0}
elif [ "$SCENARIO" -eq 1 ]; then
  # Propensity noise only: need alpha_e, c_e
  if [ -z "$ALPHA_E" ] || [ -z "$C_E" ]; then
    echo "Error: Scenario 1 requires ALPHA_E and C_E"
    exit 1
  fi
  ALPHA_MU=${ALPHA_MU:-0.5}
  C_MU=${C_MU:-1.0}
elif [ "$SCENARIO" -eq 2 ]; then
  # Outcome noise only: need alpha_mu, c_mu
  if [ -z "$ALPHA_MU" ] || [ -z "$C_MU" ]; then
    echo "Error: Scenario 2 requires ALPHA_MU and C_MU"
    exit 1
  fi
  ALPHA_E=${ALPHA_E:-0.5}
  C_E=${C_E:-1.0}
elif [ "$SCENARIO" -eq 3 ]; then
  # Both noisy: need alpha_e, alpha_mu, c_e, c_mu
  if [ -z "$ALPHA_E" ] || [ -z "$ALPHA_MU" ]; then
    echo "Error: Scenario 3 requires ALPHA_E and ALPHA_MU"
    exit 1
  fi
  # For scenario 3, typically c_e = c_mu = 1.0 (can override)
  C_E=${C_E:-1.0}
  C_MU=${C_MU:-1.0}
fi

# Directories
PROJECT_DIR="${HOME}/surrogate-transportability"
SLURM_DIR="${PROJECT_DIR}/cluster/aipw_robustness/slurm"
RESULTS_DIR="${PROJECT_DIR}/cluster/aipw_robustness/results"
CONFIG_FILE="${PROJECT_DIR}/cluster/aipw_robustness/config/aipw_grid.yaml"

# Scratch directory for temporary storage
SCRATCH_DIR="/n/scratch/users/${USER:0:1}/${USER}/aipw_robustness"
mkdir -p $SCRATCH_DIR

# Create batch identifier
BATCH_ID=$(printf "%03d" $SLURM_ARRAY_TASK_ID)
SETTING_ID="s${SCENARIO}_n${N}_a1_$(echo $ALPHA_1 | sed 's/\.//g')"

if [ "$SCENARIO" -eq 1 ] || [ "$SCENARIO" -eq 3 ]; then
  SETTING_ID="${SETTING_ID}_ae_$(echo $ALPHA_E | sed 's/\.//g')_ce_$(echo $C_E | sed 's/\.//g')"
fi

if [ "$SCENARIO" -eq 2 ] || [ "$SCENARIO" -eq 3 ]; then
  SETTING_ID="${SETTING_ID}_amu_$(echo $ALPHA_MU | sed 's/\.//g')_cmu_$(echo $C_MU | sed 's/\.//g')"
fi

OUTPUT_FILE="${SCRATCH_DIR}/${SETTING_ID}_batch_${BATCH_ID}.rds"

echo "===================================================================="
echo "AIPW Robustness Study - Job ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
echo "===================================================================="
echo "Scenario: $SCENARIO"
echo "Sample size: n = $N"
echo "Confounding: α₁ = $ALPHA_1"
echo "Propensity: α_e = $ALPHA_E, c_e = $C_E"
echo "Outcome: α_μ = $ALPHA_MU, c_μ = $C_MU"
echo "Replications: $REP_START to $REP_END (${REPS_PER_JOB} reps)"
echo "Output: $OUTPUT_FILE"
echo "===================================================================="

# Change to project directory
cd $PROJECT_DIR

# Run replications in a loop
echo "Starting replications..."

# Initialize results storage
TEMP_RESULTS="${SCRATCH_DIR}/${SETTING_ID}_batch_${BATCH_ID}_temp"
mkdir -p $TEMP_RESULTS

for REP_ID in $(seq $REP_START $REP_END); do
  REP_FILE="${TEMP_RESULTS}/rep_${REP_ID}.rds"

  echo "[$(date +'%H:%M:%S')] Running replication $REP_ID..."

  Rscript ${SLURM_DIR}/run_single_replication.R \
    --scenario=$SCENARIO \
    --n=$N \
    --alpha_1=$ALPHA_1 \
    --alpha_e=$ALPHA_E \
    --alpha_mu=$ALPHA_MU \
    --c_e=$C_E \
    --c_mu=$C_MU \
    --rep_id=$REP_ID \
    --output=$REP_FILE \
    --config=$CONFIG_FILE

  if [ $? -ne 0 ]; then
    echo "ERROR: Replication $REP_ID failed"
  fi
done

# Combine batch results
echo "Combining batch results..."
Rscript -e "
library(purrr)
files <- list.files('${TEMP_RESULTS}', pattern = 'rep_.*\\\\.rds$', full.names = TRUE)
results <- map_dfr(files, readRDS)
saveRDS(results, '${OUTPUT_FILE}')
cat(sprintf('Combined %d replications into %s\n', nrow(results), '${OUTPUT_FILE}'))
"

# Copy to permanent storage
mkdir -p ${RESULTS_DIR}/${SETTING_ID}
cp $OUTPUT_FILE ${RESULTS_DIR}/${SETTING_ID}/
echo "Copied results to ${RESULTS_DIR}/${SETTING_ID}/"

# Clean up temporary files
rm -rf $TEMP_RESULTS

echo "===================================================================="
echo "Job complete: $(date)"
echo "===================================================================="
