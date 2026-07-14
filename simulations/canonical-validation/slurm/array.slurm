#!/bin/bash
# =============================================================================
# array.slurm -- SLURM array job for the "canonical-validation" study
# =============================================================================
# NOT run directly. submit.sh sets the sizing (#SBATCH --array, --time, --mem)
# on the sbatch command line and exports the variables below. This script maps
# its array index to a GLOBAL task id, prepares scratch, and runs one task.
#
# Exported by submit.sh (via --export):
#   STUDY_DIR    absolute path to the study dir (config/, R/, slurm/)
#   SCRATCH_DIR  run-specific scratch dir (task files + logs live here)
#   REPS_PER_JOB units per task
#   ARRAY_OFFSET added to SLURM_ARRAY_TASK_ID to get the global task id
#                (arrays are chunked at <=1000; wave k covers a different range)
# =============================================================================
#SBATCH --job-name=canonical-validation
#SBATCH --partition=short
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
# --array, --time, --mem, --output, --error are supplied by submit.sh.

set -euo pipefail

# --- Module environment (module R has no devtools; use library()) ------------
module load gcc/14.2.0 2>/dev/null || module load gcc || true
module load R/4.4.2   2>/dev/null || module load R

# --- Global task id -----------------------------------------------------------
GLOBAL_TASK_ID=$(( SLURM_ARRAY_TASK_ID + ARRAY_OFFSET ))

echo "[$(date '+%F %T')] host=$(hostname) array_idx=${SLURM_ARRAY_TASK_ID} offset=${ARRAY_OFFSET} global_task=${GLOBAL_TASK_ID}"

mkdir -p "${SCRATCH_DIR}"

# --- SIGTERM trap (M3): SLURM sends SIGTERM then (after grace) SIGKILL on a
# wall-time TIMEOUT. Report how many per-unit partials this task flushed so the
# over-run is visibly recoverable (a resubmit skips completed units). The
# "received SIGTERM" line is the sentinel monitor.sh scans for.
on_term() {
  local pdir="${SCRATCH_DIR}/partials"
  local n=0
  [[ -d "${pdir}" ]] && n=$(find "${pdir}" -maxdepth 1 -name 'unit_*.rds' 2>/dev/null | wc -l | tr -d ' ')
  echo "[$(date '+%F %T')] global_task=${GLOBAL_TASK_ID} received SIGTERM (likely TIMEOUT); ${n} unit partial(s) flushed and safe. Resubmit to resume." >&2
  exit 143
}
trap on_term TERM

# --- Run one task's block of units (backgrounded so the trap can fire) --------
Rscript "${STUDY_DIR}/slurm/run_replication.R" \
  --task-id      "${GLOBAL_TASK_ID}" \
  --reps-per-job "${REPS_PER_JOB}" \
  --study-dir    "${STUDY_DIR}" \
  --scratch-dir  "${SCRATCH_DIR}" &
# `wait` returns the child's exit status; `|| status=$?` keeps `set -e` from
# aborting before we print the "finished with status N" sentinel monitor.sh needs.
status=0
wait $! || status=$?

echo "[$(date '+%F %T')] global_task=${GLOBAL_TASK_ID} finished with status ${status}"
exit "${status}"
