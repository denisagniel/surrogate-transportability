#!/bin/bash
# =============================================================================
# prep_offline.sh -- one-command offline prep as a chained SLURM pipeline
# =============================================================================
# Replaces the serial prep_offline.R (~2 hr) with a parallel array (~minutes):
#
#   Step 1  prep_seeds.R        (1 job)   -> ensemble_seeds.rds + prep_ntasks.txt
#   Step 2  prep_truth_array    (N tasks) -> config/truth/truth_<id>.rds   [PARALLEL]
#   Step 3  prep_truth_combine  (1 job)   -> config/truth_table.rds
#
# Step 1 self-submits Steps 2+3 at its end, because the array size N = nrow(GRID)
# is only known once the balanced seeds are chosen. Everything is dependency-
# chained, so you run ONE command and wait.
#
# Usage (on O2, from the study dir; NOT the login node for heavy R, but this
# launcher itself is light -- it just submits jobs):
#   bash slurm/prep_offline.sh [SCAN] [PER_BIN] [M_REF]
#   e.g. bash slurm/prep_offline.sh 8000:8800 7 100000
# =============================================================================

set -euo pipefail

SCAN="${1:-8000:8800}"
PER_BIN="${2:-7}"
M_REF="${3:-100000}"

SLURM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDY_DIR="$(dirname "${SLURM_DIR}")"
LOG_DIR="${STUDY_DIR}/config/prep_logs"
mkdir -p "${LOG_DIR}" "${STUDY_DIR}/config/truth"

echo "=============================================================="
echo " generality-validation OFFLINE PREP (chained pipeline)"
echo " scan=${SCAN}  per_bin=${PER_BIN}  m_ref=${M_REF}"
echo " study_dir=${STUDY_DIR}"
echo "=============================================================="

# --- Step 1: balanced seeds (a real batch job; ~15-25 min, single core) ------
# At its END it submits Steps 2+3 (needs prep_ntasks.txt written first). We wrap
# the R call + the follow-on sbatch in one --wrap script.
STEP1_CMD="module load gcc/14.2.0 2>/dev/null || module load gcc || true; \
module load R/4.4.2 2>/dev/null || module load R; \
Rscript '${STUDY_DIR}/slurm/prep_seeds.R' --study-dir '${STUDY_DIR}' --scan '${SCAN}' --per-bin ${PER_BIN}; \
N=\$(cat '${STUDY_DIR}/config/prep_ntasks.txt'); \
echo \"seeds done; N=\${N} configs -> submitting truth array\"; \
AID=\$(sbatch --parsable --array=1-\${N} \
  --output='${LOG_DIR}/truth_%A_%a.out' --error='${LOG_DIR}/truth_%A_%a.err' \
  --export=ALL,STUDY_DIR='${STUDY_DIR}',M_REF='${M_REF}' \
  '${SLURM_DIR}/prep_truth_array.slurm'); \
echo \"truth array = \${AID}\"; \
sbatch --parsable --dependency=afterok:\${AID} \
  --job-name=genval-truthcombine --partition=short --time=0-00:15:00 --mem=2G \
  --output='${LOG_DIR}/combine_%j.out' --error='${LOG_DIR}/combine_%j.err' \
  --wrap=\"module load gcc/14.2.0 2>/dev/null || module load gcc || true; module load R/4.4.2 2>/dev/null || module load R; Rscript '${STUDY_DIR}/slurm/prep_truth_combine.R' --study-dir '${STUDY_DIR}'\""

JID=$(sbatch --parsable \
  --job-name=genval-seeds --partition=short --time=0-00:45:00 --mem=2G \
  --output="${LOG_DIR}/seeds_%j.out" --error="${LOG_DIR}/seeds_%j.err" \
  --wrap="${STEP1_CMD}")

echo "Submitted Step 1 (seeds) job ${JID}."
echo "It self-submits the truth array and the combine job on success."
echo "Watch: squeue -u \$USER   |   logs in ${LOG_DIR}/"
echo "When done: config/truth_table.rds exists -> run slurm/profile_timing.R"
