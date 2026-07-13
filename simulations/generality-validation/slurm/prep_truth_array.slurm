#!/bin/bash
# =============================================================================
# prep_truth_array.slurm -- STEP 2 array: one task = exact truth for one config
# =============================================================================
# Submitted by prep_offline.sh with --array=1-<N> (N = nrow(GRID)) after Step 1
# fixes the ensemble seeds. Each task computes rho_true for its config_id and
# writes config/truth/truth_<id>.rds. Exported: STUDY_DIR, M_REF.
# =============================================================================
#SBATCH --job-name=genval-truth
#SBATCH --partition=short
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=0-00:20:00
# --array, --output, --error supplied by prep_offline.sh.

set -euo pipefail
module load gcc/14.2.0 2>/dev/null || module load gcc || true
module load R/4.4.2   2>/dev/null || module load R

echo "[$(date '+%F %T')] host=$(hostname) truth config_id=${SLURM_ARRAY_TASK_ID}"
Rscript "${STUDY_DIR}/slurm/prep_truth_one.R" \
  --config-id "${SLURM_ARRAY_TASK_ID}" \
  --study-dir "${STUDY_DIR}" \
  --m-ref     "${M_REF}"
